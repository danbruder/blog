defmodule Blog.AnalyticsTest do
  use ExUnit.Case, async: false

  alias Blog.Analytics

  test "track/2 writes an event that can be read back" do
    event_name = "test_event_#{System.unique_integer([:positive])}"

    Analytics.track(event_name, %{
      path: "/notes",
      referrer: "https://www.google.com/search?q=blog",
      session_id: "sailor-123",
      country: "US",
      props: %{foo: "bar"}
    })

    :ok = Analytics.flush()

    {:ok, columns, rows} =
      Analytics.query(
        "SELECT event_name, path, referrer, referrer_host, session_id, country, props FROM events WHERE event_name = $1",
        [event_name]
      )

    assert columns == [
             "event_name",
             "path",
             "referrer",
             "referrer_host",
             "session_id",
             "country",
             "props"
           ]

    assert [
             [
               ^event_name,
               "/notes",
               "https://www.google.com/search?q=blog",
               "google.com",
               "sailor-123",
               "US",
               props_json
             ]
           ] = rows

    assert Jason.decode!(props_json) == %{"foo" => "bar"}
  end

  test "track/2 tolerates missing optional attrs" do
    event_name = "test_event_#{System.unique_integer([:positive])}"

    Analytics.track(event_name)
    :ok = Analytics.flush()

    {:ok, _columns, rows} =
      Analytics.query(
        "SELECT path, referrer_host, props FROM events WHERE event_name = $1",
        [event_name]
      )

    assert [[nil, nil, nil]] = rows
  end

  describe "buffering" do
    test "track/2 buffers the event in memory until flush/0 forces a bulk write" do
      event_name = "test_event_#{System.unique_integer([:positive])}"

      Analytics.track(event_name)

      {:ok, _columns, rows} =
        Analytics.query("SELECT path FROM events WHERE event_name = $1", [event_name])

      assert rows == []

      :ok = Analytics.flush()

      {:ok, _columns, rows} =
        Analytics.query("SELECT path FROM events WHERE event_name = $1", [event_name])

      assert length(rows) == 1
    end

    test "the buffer flushes itself once it reaches its size threshold" do
      event_name = "test_event_#{System.unique_integer([:positive])}"

      # Matches Blog.Analytics's private @flush_max_buffer. GenServer.call/2
      # below only runs after every prior cast from this same process has
      # been handled, so if this count is reached without ever calling
      # flush/0, the rows being visible proves the size trigger fired on
      # its own rather than the query happening to run after some later
      # timer-based flush.
      for _ <- 1..200, do: Analytics.track(event_name)

      {:ok, _columns, rows} =
        Analytics.query("SELECT COUNT(*) FROM events WHERE event_name = $1", [event_name])

      assert [[200]] = rows
    end
  end

  describe "stats/3" do
    test "aggregates views, sessions, and per-path/country/referrer breakdowns" do
      session_a = "sess_#{System.unique_integer([:positive])}"
      session_b = "sess_#{System.unique_integer([:positive])}"
      base = unique_base()

      insert_page_view(session_a, "/a", "US", "https://www.google.com/search", base)

      insert_page_view(
        session_a,
        "/b",
        "US",
        "https://www.google.com/search",
        DateTime.add(base, 30, :second)
      )

      insert_page_view(session_b, "/a", "CA", nil, base)

      {:ok, report} =
        Analytics.stats(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute))

      assert report.summary.views == 3
      assert report.summary.sessions == 2

      assert %{path: "/a", views: 2, sessions: 2} =
               Enum.find(report.top_paths, &(&1.path == "/a"))

      assert %{path: "/b", views: 1, sessions: 1} =
               Enum.find(report.top_paths, &(&1.path == "/b"))

      assert %{"US" => 1, "CA" => 1} =
               report.top_countries |> Map.new(&{&1.country, &1.sessions})

      assert %{"google.com" => 1, "Direct" => 1} =
               report.top_referrers |> Map.new(&{&1.source, &1.sessions})
    end

    test "computes avg_duration_seconds for the session's gap to its next view" do
      session_id = "sess_#{System.unique_integer([:positive])}"
      base = unique_base()

      insert_page_view(session_id, "/a", "US", nil, base)
      insert_page_view(session_id, "/b", "US", nil, DateTime.add(base, 42, :second))

      {:ok, report} =
        Analytics.stats(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute))

      path_a = Enum.find(report.top_paths, &(&1.path == "/a"))
      assert path_a.avg_duration_seconds == 42.0
    end

    test "excludes views outside the given range" do
      session_id = "sess_#{System.unique_integer([:positive])}"
      base = unique_base()

      insert_page_view(session_id, "/out-of-range", "US", nil, DateTime.add(base, -10, :day))

      {:ok, report} = Analytics.stats(DateTime.add(base, -1, :day), DateTime.add(base, 1, :day))

      refute Enum.any?(report.top_paths, &(&1.path == "/out-of-range"))
    end

    test "referrer_contains filters to matching referrer hosts" do
      session_google = "sess_#{System.unique_integer([:positive])}"
      session_direct = "sess_#{System.unique_integer([:positive])}"
      base = unique_base()

      insert_page_view(session_google, "/filtered-a", "US", "https://google.com/search", base)
      insert_page_view(session_direct, "/filtered-b", "US", nil, base)

      {:ok, report} =
        Analytics.stats(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute),
          referrer_contains: "google"
        )

      paths = Enum.map(report.top_paths, & &1.path)
      assert "/filtered-a" in paths
      refute "/filtered-b" in paths
    end
  end

  defp insert_page_view(session_id, path, country, referrer, %DateTime{} = occurred_at) do
    {:ok, _columns, _rows} =
      Analytics.query(
        """
        INSERT INTO events (occurred_at_us, event_name, path, referrer, referrer_host, session_id, country)
        VALUES ($1, 'page_view', $2, $3, $4, $5, $6)
        """,
        [
          DateTime.to_unix(occurred_at, :microsecond),
          path,
          referrer,
          referrer_host(referrer),
          session_id,
          country
        ]
      )
  end

  # Every test shares one in-memory DuckDB instance for the whole suite, so
  # a real `DateTime.utc_now()` window would pick up other tests' rows.
  # Spacing unique bases by an hour keeps each test's ±1 minute query window
  # from ever overlapping another test's.
  defp unique_base do
    DateTime.add(~U[2020-01-01 00:00:00Z], System.unique_integer([:positive]) * 3600, :second)
  end

  defp referrer_host(nil), do: nil

  defp referrer_host(referrer),
    do: referrer |> URI.parse() |> Map.fetch!(:host) |> String.replace_prefix("www.", "")
end
