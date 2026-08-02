defmodule Blog.Analytics do
  @moduledoc """
  Records page views and other visitor interaction events to a DuckDB file
  on the persistent data volume, for first-party analytics without sending
  visitor data to a third party.

  Writes are serialized through this single GenServer (DuckDB is designed
  for one writer at a time) and fire-and-forget from the caller's
  perspective, so tracking a page view never blocks or crashes a request.

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
  # A gap longer than this between two page views in the same session isn't
  # "time on page" so much as an abandoned/backgrounded tab; treat it as
  # unknown rather than skewing the average.
  @max_duration_us 30 * 60 * 1_000_000

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

  @doc "Blocks until all previously-cast track/2 calls have been written. Test-only."
  def flush, do: GenServer.call(__MODULE__, :flush)

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

    {:ok, %{conn: conn, db: db, avg_supported?: ensure_core_functions(conn)}}
  end

  # `SUM`/`AVG` live in DuckDB's `core_functions` extension, which this
  # precompiled build doesn't bundle. Installing it needs network access
  # (once cached to disk, later boots reuse the cached copy); if that fails
  # -- offline, read-only filesystem, whatever -- reporting just falls back
  # to reporting the average as unavailable instead of crashing the app.
  defp ensure_core_functions(conn) do
    with {:ok, _} <- Duckdbex.query(conn, "INSTALL core_functions"),
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

  @impl true
  def handle_cast({:track, event_name, attrs}, state) do
    referrer = Map.get(attrs, :referrer)
    props = Map.get(attrs, :props)

    params = [
      DateTime.to_unix(DateTime.utc_now(), :microsecond),
      event_name,
      Map.get(attrs, :path),
      referrer,
      referrer_host(referrer),
      Map.get(attrs, :session_id),
      Map.get(attrs, :country),
      props && Jason.encode!(props)
    ]

    sql = """
    INSERT INTO #{@table}
      (occurred_at_us, event_name, path, referrer, referrer_host, session_id, country, props)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    """

    case Duckdbex.query(state.conn, sql, params) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        Logger.warning("Blog.Analytics: failed to record #{event_name}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:stats, from, to, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 20)
    where_sql = ctes(where_clause(opts[:referrer_contains]))
    params = where_params(from, to, opts[:referrer_contains])
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
  def handle_call({:query, sql, params}, _from, state) do
    reply =
      case Duckdbex.query(state.conn, sql, params) do
        {:ok, result} -> {:ok, Duckdbex.columns(result), Duckdbex.fetch_all(result)}
        error -> error
      end

    {:reply, reply, state}
  end

  # Lets tests wait for previously-cast events to be written before querying,
  # since GenServer.cast/2 doesn't wait for the message to be processed.
  @impl true
  def handle_call(:flush, _from, state), do: {:reply, :ok, state}

  defp where_clause(nil), do: ""
  defp where_clause(""), do: ""
  defp where_clause(_referrer_contains), do: " AND referrer_host LIKE $4"

  defp where_params(from, to, nil), do: base_where_params(from, to)
  defp where_params(from, to, ""), do: base_where_params(from, to)

  defp where_params(from, to, referrer_contains) do
    base_where_params(from, to) ++ ["%" <> String.downcase(referrer_contains) <> "%"]
  end

  defp base_where_params(from, to) do
    [@page_view_event, DateTime.to_unix(from, :microsecond), DateTime.to_unix(to, :microsecond)]
  end

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
end
