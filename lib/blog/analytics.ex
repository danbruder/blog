defmodule Blog.Analytics do
  @moduledoc """
  Records page views and other visitor interaction events to a DuckDB file
  on the persistent data volume, for first-party analytics without sending
  visitor data to a third party.

  Writes are serialized through this single GenServer (DuckDB is designed
  for one writer at a time) and fire-and-forget from the caller's
  perspective, so tracking a page view never blocks or crashes a request.

  `track/2` doesn't hit DuckDB at all -- it buffers the event in memory and
  returns immediately. The buffer is flushed to disk in one bulk write via
  DuckDB's Appender (see `write_rows/2`) every few seconds, once it reaches
  a couple hundred events, or on a `flush/0` call (which `stats/3` does
  automatically, so reads are always current even though writes lag by a
  few seconds).

  Timestamps are stored as `occurred_at_us`, a plain `BIGINT` of
  microseconds since the Unix epoch (UTC), rather than a `TIMESTAMP`: the
  precompiled DuckDB build this app uses doesn't bundle the
  `core_functions` extension, so even `now()`/`date_diff` aren't in the
  catalog until that extension is installed (see `ensure_core_functions/1`)
  — plain integer arithmetic sidesteps that dependency entirely for
  filtering and for the LEAD-based "time on page" calculation. `SUM`/`AVG`
  are also part of that extension, so the reporting queries below ask for
  them but degrade to a literal `NULL` (average time on page shows as
  unavailable) if the extension can't be loaded, e.g. no network at boot.
  """

  use GenServer

  require Logger

  @table "events"
  @page_view_event "page_view"
  @kudos_event "kudos"
  # A gap longer than this between two page views in the same session isn't
  # "time on page" so much as an abandoned/backgrounded tab; treat it as
  # unknown rather than skewing the average.
  @max_duration_us 30 * 60 * 1_000_000
  @flush_interval_ms 5_000
  @flush_max_buffer 200

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records an event. `attrs` may include `:path`, `:referrer`, `:session_id`,
  `:country`, and `:props` (an arbitrary JSON-encodable map of
  event-specific details, e.g. `%{game: "snake", score: 12}`).
  """
  def track(event_name, attrs \\ %{}) when is_binary(event_name) and is_map(attrs) do
    GenServer.cast(__MODULE__, {:track, event_name, attrs})
  end

  @doc """
  Returns aggregated `"page_view"` stats for `[from, to)` (both `DateTime`):

      {:ok, %{
        summary: %{views: 123, sessions: 45, avg_duration_seconds: 38.2},
        top_paths: [%{path:, views:, sessions:, avg_duration_seconds:}, ...],
        top_countries: [%{country:, sessions:}, ...],
        top_referrers: [%{source:, sessions:}, ...]
      }}

  All grouping/counting/averaging runs as SQL in DuckDB; the map above is
  already the final report. `opts`:

    * `:referrer_contains` - only count views whose referrer host contains
      this substring (case-insensitive), e.g. `"google"`
    * `:direct` - if truthy, only count views with no referrer at all
      (takes precedence over `:referrer_contains`)
    * `:path` - only count views of this exact path
    * `:country` - only count views from this exact country code, or
      `"Unknown"` for views with no resolved country
    * `:limit` - max rows per breakdown list (default 20)

  `source` in `top_referrers` is a bare host (`"google.com"`, `"Direct"`
  for no referrer). `avg_duration_seconds` is `nil` when the underlying
  DuckDB build can't compute it (see moduledoc) or there's no data.
  """
  def stats(from, to, opts \\ []) do
    GenServer.call(__MODULE__, {:stats, from, to, opts})
  end

  @doc """
  Runs a read-only SQL query against the events database (e.g. from IEx for
  ad hoc reporting). Returns `{:ok, columns, rows}` or `{:error, reason}`.
  """
  def query(sql, params \\ []) do
    GenServer.call(__MODULE__, {:query, sql, params})
  end

  @doc "Forces an immediate bulk write of any buffered events. Also handy in tests."
  def flush, do: GenServer.call(__MODULE__, :flush)

  @doc """
  Records a "kudos" event for `path` -- a reader holding down the thumbs-up
  button on a post for the full 5 seconds. `session_id` is optional and
  purely informational (matches `track/2`'s convention); double-submission
  is prevented upstream by `BlogWeb.KudosController`, not here.
  """
  def track_kudos(path, session_id \\ nil) do
    track(@kudos_event, %{path: path, session_id: session_id})
  end

  @doc """
  Returns per-post stats for the footer shown under each post:

      {:ok, %{views_all_time: 123, views_last_week: 4, kudos: 7}}

  `views_*` count `"page_view"` events for the exact `path`; `kudos` counts
  `"kudos"` events for it. "Last week" is a rolling 7 days ending now, not a
  calendar week.
  """
  def post_stats(path) do
    GenServer.call(__MODULE__, {:post_stats, path})
  end

  @impl true
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    {:ok, db} = if path == :memory, do: Duckdbex.open(), else: Duckdbex.open(path)
    {:ok, conn} = Duckdbex.connection(db)

    {:ok, _result} =
      Duckdbex.query(conn, """
      CREATE TABLE IF NOT EXISTS #{@table} (
        occurred_at_us BIGINT NOT NULL,
        event_name VARCHAR NOT NULL,
        path VARCHAR,
        referrer VARCHAR,
        referrer_host VARCHAR,
        session_id VARCHAR,
        country VARCHAR,
        props VARCHAR
      )
      """)

    schedule_flush()

    {:ok, %{conn: conn, db: db, avg_supported?: ensure_core_functions(conn, path), buffer: []}}
  end

  @impl true
  def terminate(_reason, state) do
    flush_buffer(state)
    :ok
  end

  # `SUM`/`AVG` live in DuckDB's `core_functions` extension, which this
  # precompiled build doesn't bundle. Installing it needs network access
  # (once cached to disk, later boots reuse the cached copy) *and* a
  # writable directory to cache it in -- DuckDB defaults to one under
  # $HOME, which in the deployed container is the `nobody` user's
  # `/nonexistent`, so that's pointed explicitly at a directory next to the
  # analytics file itself (on the same persistent volume, so the download
  # survives restarts). If any of this fails -- offline, read-only
  # filesystem, whatever -- reporting just falls back to reporting the
  # average as unavailable instead of crashing the app.
  defp ensure_core_functions(conn, path) do
    extension_dir = extension_directory(path)
    File.mkdir_p!(extension_dir)
    escaped_dir = String.replace(extension_dir, "'", "''")

    # SET doesn't go through the regular prepared-statement parameter path
    # (binding $1 here fails with "value not provided"), so this has to be
    # interpolated -- safe since extension_dir only ever comes from our own
    # config (ANALYTICS_PATH / the default), never user input.
    with {:ok, _} <- Duckdbex.query(conn, "SET extension_directory = '#{escaped_dir}'"),
         {:ok, _} <- Duckdbex.query(conn, "INSTALL core_functions"),
         {:ok, _} <- Duckdbex.query(conn, "LOAD core_functions") do
      true
    else
      {:error, reason} ->
        Logger.warning(
          "Blog.Analytics: couldn't load the DuckDB core_functions extension (#{inspect(reason)}); " <>
            "average time-on-page will be reported as unavailable"
        )

        false
    end
  end

  defp extension_directory(:memory) do
    Path.join(System.tmp_dir!(), "blog_analytics_duckdb_extensions")
  end

  defp extension_directory(path), do: Path.join(Path.dirname(path), "duckdb_extensions")

  @impl true
  def handle_cast({:track, event_name, attrs}, state) do
    buffer = [build_row(event_name, attrs) | state.buffer]

    state =
      if length(buffer) >= @flush_max_buffer do
        flush_buffer(%{state | buffer: buffer})
      else
        %{state | buffer: buffer}
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:scheduled_flush, state) do
    schedule_flush()
    {:noreply, flush_buffer(state)}
  end

  @impl true
  def handle_call({:stats, from, to, opts}, _from, state) do
    state = flush_buffer(state)
    limit = Keyword.get(opts, :limit, 20)
    {filter_sql, params} = where_clause_and_params(from, to, opts)
    where_sql = ctes(filter_sql)
    avg_expr = if state.avg_supported?, do: "AVG(duration_us)", else: "NULL"

    reply =
      with {:ok, summary} <- fetch_one(state.conn, where_sql <> summary_sql(avg_expr), params),
           {:ok, top_paths} <-
             fetch_all(state.conn, where_sql <> top_paths_sql(avg_expr, limit), params),
           {:ok, top_countries} <-
             fetch_all(state.conn, where_sql <> top_countries_sql(limit), params),
           {:ok, top_referrers} <-
             fetch_all(state.conn, where_sql <> top_referrers_sql(limit), params) do
        {:ok,
         %{
           summary: decode_summary(summary),
           top_paths: Enum.map(top_paths, &decode_top_path/1),
           top_countries: Enum.map(top_countries, &decode_country/1),
           top_referrers: Enum.map(top_referrers, &decode_referrer/1)
         }}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:post_stats, path}, _from, state) do
    state = flush_buffer(state)
    week_ago_us = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.to_unix(:microsecond)

    sql = """
    SELECT
      (SELECT COUNT(*) FROM #{@table} WHERE event_name = $1 AND path = $2) AS views_all_time,
      (SELECT COUNT(*) FROM #{@table} WHERE event_name = $1 AND path = $2 AND occurred_at_us >= $3)
        AS views_last_week,
      (SELECT COUNT(*) FROM #{@table} WHERE event_name = $4 AND path = $2) AS kudos
    """

    reply =
      with {:ok, [views_all_time, views_last_week, kudos]} <-
             fetch_one(state.conn, sql, [@page_view_event, path, week_ago_us, @kudos_event]) do
        {:ok, %{views_all_time: views_all_time, views_last_week: views_last_week, kudos: kudos}}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:query, sql, params}, _from, state) do
    reply =
      case Duckdbex.query(state.conn, sql, params) do
        {:ok, result} -> {:ok, Duckdbex.columns(result), Duckdbex.fetch_all(result)}
        error -> error
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    {:reply, :ok, flush_buffer(state)}
  end

  # Builds the `AND ...` fragment (with `$4`, `$5`, ... placeholders) and its
  # matching params list together, so the SQL and the bindings can never
  # drift out of sync the way keeping them in two separate functions risked.
  defp where_clause_and_params(from, to, opts) do
    base_params = [
      @page_view_event,
      DateTime.to_unix(from, :microsecond),
      DateTime.to_unix(to, :microsecond)
    ]

    [referrer_filter(opts), path_filter(opts[:path]), country_filter(opts[:country])]
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce({"", base_params}, fn
      {template, :no_param}, {sql, params} ->
        {sql <> " AND " <> template, params}

      {template, value}, {sql, params} ->
        placeholder = "$#{length(params) + 1}"
        {sql <> " AND " <> String.replace(template, "?", placeholder), params ++ [value]}
    end)
  end

  defp referrer_filter(opts) do
    cond do
      opts[:direct] ->
        {"referrer_host IS NULL", :no_param}

      present?(opts[:referrer_contains]) ->
        {"referrer_host LIKE ?", "%" <> String.downcase(opts[:referrer_contains]) <> "%"}

      true ->
        nil
    end
  end

  defp path_filter(nil), do: nil
  defp path_filter(""), do: nil
  defp path_filter(path), do: {"path = ?", path}

  defp country_filter(nil), do: nil
  defp country_filter(""), do: nil
  defp country_filter("Unknown"), do: {"country IS NULL", :no_param}
  defp country_filter(country), do: {"country = ?", country}

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_value), do: true

  defp ctes(referrer_filter_sql) do
    """
    WITH filtered AS (
      SELECT occurred_at_us, path, referrer_host, session_id, country
      FROM #{@table}
      WHERE event_name = $1 AND occurred_at_us >= $2 AND occurred_at_us < $3#{referrer_filter_sql}
    ),
    with_duration AS (
      SELECT path, referrer_host, session_id, country,
             LEAD(occurred_at_us) OVER (PARTITION BY session_id ORDER BY occurred_at_us) - occurred_at_us
               AS duration_us
      FROM filtered
    ),
    capped AS (
      SELECT path, referrer_host, session_id, country,
             CASE WHEN duration_us > 0 AND duration_us <= #{@max_duration_us} THEN duration_us END
               AS duration_us
      FROM with_duration
    )
    """
  end

  defp summary_sql(avg_expr) do
    """
    SELECT
      (SELECT COUNT(*) FROM filtered) AS views,
      (SELECT COUNT(DISTINCT session_id) FROM filtered) AS sessions,
      (SELECT #{avg_expr} FROM capped) AS avg_duration_us
    """
  end

  defp top_paths_sql(avg_expr, limit) do
    """
    SELECT path, COUNT(*) AS views, COUNT(DISTINCT session_id) AS sessions,
           #{avg_expr} AS avg_duration_us
    FROM capped
    GROUP BY path
    ORDER BY views DESC
    LIMIT #{limit}
    """
  end

  defp top_countries_sql(limit) do
    """
    SELECT COALESCE(country, 'Unknown') AS country, COUNT(DISTINCT session_id) AS sessions
    FROM filtered
    GROUP BY COALESCE(country, 'Unknown')
    ORDER BY sessions DESC
    LIMIT #{limit}
    """
  end

  defp top_referrers_sql(limit) do
    """
    SELECT COALESCE(referrer_host, 'Direct') AS source, COUNT(DISTINCT session_id) AS sessions
    FROM filtered
    GROUP BY COALESCE(referrer_host, 'Direct')
    ORDER BY sessions DESC
    LIMIT #{limit}
    """
  end

  defp fetch_one(conn, sql, params) do
    case Duckdbex.query(conn, sql, params) do
      {:ok, result} -> {:ok, hd(Duckdbex.fetch_all(result))}
      error -> error
    end
  end

  defp fetch_all(conn, sql, params) do
    case Duckdbex.query(conn, sql, params) do
      {:ok, result} -> {:ok, Duckdbex.fetch_all(result)}
      error -> error
    end
  end

  defp decode_summary([views, sessions, avg_duration_us]) do
    %{views: views, sessions: sessions, avg_duration_seconds: to_seconds(avg_duration_us)}
  end

  defp decode_top_path([path, views, sessions, avg_duration_us]) do
    %{
      path: path,
      views: views,
      sessions: sessions,
      avg_duration_seconds: to_seconds(avg_duration_us)
    }
  end

  defp decode_country([country, sessions]), do: %{country: country, sessions: sessions}
  defp decode_referrer([source, sessions]), do: %{source: source, sessions: sessions}

  defp to_seconds(nil), do: nil
  defp to_seconds(microseconds), do: microseconds / 1_000_000

  defp referrer_host(nil), do: nil
  defp referrer_host(""), do: nil

  defp referrer_host(referrer) do
    case URI.parse(referrer).host do
      nil -> nil
      host -> host |> String.downcase() |> String.replace_prefix("www.", "")
    end
  end

  defp schedule_flush, do: Process.send_after(self(), :scheduled_flush, @flush_interval_ms)

  defp build_row(event_name, attrs) do
    referrer = Map.get(attrs, :referrer)
    props = Map.get(attrs, :props)

    [
      DateTime.to_unix(DateTime.utc_now(), :microsecond),
      event_name,
      Map.get(attrs, :path),
      referrer,
      referrer_host(referrer),
      Map.get(attrs, :session_id),
      Map.get(attrs, :country),
      props && Jason.encode!(props)
    ]
  end

  defp flush_buffer(%{buffer: []} = state), do: state

  defp flush_buffer(state) do
    rows = Enum.reverse(state.buffer)

    case write_rows(state.conn, rows) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Blog.Analytics: failed to flush #{length(rows)} buffered event(s): #{inspect(reason)}"
        )
    end

    %{state | buffer: []}
  end

  # DuckDB's Appender is the fast path for writing many rows at once (vs. an
  # INSERT per event, each of which pays its own parse/plan/transaction
  # overhead) -- exactly what buffering here is for.
  defp write_rows(conn, rows) do
    with {:ok, appender} <- Duckdbex.appender(conn, @table),
         :ok <- Duckdbex.appender_add_rows(appender, rows),
         :ok <- Duckdbex.appender_flush(appender),
         :ok <- Duckdbex.appender_close(appender) do
      :ok
    end
  rescue
    error -> {:error, error}
  end
end
