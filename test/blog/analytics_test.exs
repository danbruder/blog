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

      # Blog.Analytics is one shared, singleton-named GenServer -- its
      # buffer holds every *other* concurrently-running async: false test
      # module's track/2 calls too, not just this test's. That means the
      # 200-item threshold can be tripped by a mix of senders partway
      # through this loop, flushing some of our rows early; the rest of
      # our 200 then sit in the next (not-yet-full) buffer until something
      # else's activity tops it back up. So "handled" (guaranteed above)
      # doesn't always mean "already on disk" the instant the loop above
      # returns. Poll briefly rather than asserting immediately -- still
      # well under the 5s scheduled-flush interval, so a pass here still
      # shows the size trigger (not that timer) is what wrote these.
      rows =
        eventually([[200]], fn ->
          {:ok, _columns, rows} =
            Analytics.query("SELECT COUNT(*) FROM events WHERE event_name = $1", [event_name])

          rows
        end)

      assert [[200]] = rows
    end
  end

  # Retries `fun` (which must be side-effect-safe to repeat) until it
  # returns `target`, or gives up and returns whatever the last attempt got
  # -- for asserting on state that becomes eventually consistent shortly
  # after an async trigger, without a fixed sleep that's either too short
  # (flaky) or wastes time on every passing run (too long).
  defp eventually(target, fun, attempts \\ 20) do
    case fun.() do
      ^target ->
        target

      result when attempts <= 1 ->
        result

      _ ->
        Process.sleep(10)
        eventually(target, fun, attempts - 1)
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

    test "direct: true filters to views with no referrer at all" do
      session_google = "sess_#{System.unique_integer([:positive])}"
      session_direct = "sess_#{System.unique_integer([:positive])}"
      base = unique_base()

      insert_page_view(session_google, "/direct-a", "US", "https://google.com/search", base)
      insert_page_view(session_direct, "/direct-b", "US", nil, base)

      {:ok, report} =
        Analytics.stats(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute),
          direct: true
        )

      paths = Enum.map(report.top_paths, & &1.path)
      refute "/direct-a" in paths
      assert "/direct-b" in paths
    end

    test "path: filters every breakdown down to that exact path" do
      session_a = "sess_#{System.unique_integer([:positive])}"
      session_b = "sess_#{System.unique_integer([:positive])}"
      base = unique_base()

      insert_page_view(session_a, "/path-a", "US", "https://google.com/search", base)
      insert_page_view(session_b, "/path-b", "CA", nil, base)

      {:ok, report} =
        Analytics.stats(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute),
          path: "/path-a"
        )

      assert report.summary.views == 1
      assert [%{path: "/path-a"}] = report.top_paths
      assert [%{country: "US"}] = report.top_countries
      assert [%{source: "google.com"}] = report.top_referrers
    end

    test "country: filters to that exact country, and \"Unknown\" means no country" do
      session_us = "sess_#{System.unique_integer([:positive])}"
      session_unknown = "sess_#{System.unique_integer([:positive])}"
      base = unique_base()

      insert_page_view(session_us, "/country-a", "US", nil, base)
      insert_page_view(session_unknown, "/country-b", nil, nil, base)

      {:ok, us_report} =
        Analytics.stats(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute),
          country: "US"
        )

      assert Enum.map(us_report.top_paths, & &1.path) == ["/country-a"]

      {:ok, unknown_report} =
        Analytics.stats(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute),
          country: "Unknown"
        )

      assert Enum.map(unknown_report.top_paths, & &1.path) == ["/country-b"]
    end

    test "trend defaults to day buckets and zero-fills gaps across the window" do
      session_id = "sess_#{System.unique_integer([:positive])}"
      base = trend_base()

      insert_page_view(session_id, "/a", "US", nil, base)
      insert_page_view(session_id, "/b", "US", nil, DateTime.add(base, 2, :day))

      {:ok, report} = Analytics.stats(base, DateTime.add(base, 4, :day))

      assert Enum.map(report.trend, & &1.views) == [1, 0, 1, 0]
      assert Enum.all?(report.trend, &match?(%DateTime{}, &1.at))
    end

    test "trend trims the empty run before the first real event, but not after" do
      session_id = "sess_#{System.unique_integer([:positive])}"
      base = trend_base()

      # Window is 10 days wide; the only data is on day 6, so the "all
      # time"-style scenario this guards against -- a from far earlier than
      # any real data -- has 6 days of nothing to trim, and 3 trailing days
      # of nothing to keep.
      insert_page_view(session_id, "/a", "US", nil, DateTime.add(base, 6, :day))

      {:ok, report} = Analytics.stats(base, DateTime.add(base, 10, :day))

      assert Enum.map(report.trend, & &1.views) == [1, 0, 0, 0]
      assert hd(report.trend).at == DateTime.add(base, 6, :day)
    end

    test "trend honors :trend_bucket" do
      session_id = "sess_#{System.unique_integer([:positive])}"
      base = trend_base()

      insert_page_view(session_id, "/a", "US", nil, base)
      insert_page_view(session_id, "/b", "US", nil, DateTime.add(base, 3, :hour))

      {:ok, report} =
        Analytics.stats(base, DateTime.add(base, 4, :hour), trend_bucket: :hour)

      assert Enum.map(report.trend, & &1.views) == [1, 0, 0, 1]
    end

    test "trend respects the same filters as the rest of the report" do
      session_a = "sess_#{System.unique_integer([:positive])}"
      session_b = "sess_#{System.unique_integer([:positive])}"
      base = trend_base()

      insert_page_view(session_a, "/trend-a", "US", nil, base)
      insert_page_view(session_b, "/trend-b", "CA", nil, base)

      {:ok, report} =
        Analytics.stats(base, DateTime.add(base, 1, :hour),
          path: "/trend-a",
          trend_bucket: :hour
        )

      assert Enum.map(report.trend, & &1.views) == [1]
    end

    test "filters combine (AND) rather than override each other" do
      session_id = "sess_#{System.unique_integer([:positive])}"
      base = unique_base()

      insert_page_view(session_id, "/combo-a", "US", "https://google.com/search", base)
      insert_page_view(session_id, "/combo-b", "US", "https://google.com/search", base)

      {:ok, report} =
        Analytics.stats(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute),
          path: "/combo-a",
          country: "US",
          referrer_contains: "google"
        )

      assert Enum.map(report.top_paths, & &1.path) == ["/combo-a"]
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

  # Trend tests query multi-hour/multi-day windows, wider than the ±1 minute
  # windows the rest of this file uses -- too wide to rely on unique_base/0's
  # hour-scale spacing for isolation. Anchored to a different century and
  # spread across ~1900 years there, so no other test's rows can ever fall
  # inside a trend test's window regardless of unique_integer ordering.
  # Always midnight-aligned, so day and hour bucket edges land exactly where
  # the assertions expect.
  defp trend_base do
    DateTime.add(
      ~U[2100-01-01 00:00:00Z],
      rem(System.unique_integer([:positive]), 100_000) * 7,
      :day
    )
  end

  defp referrer_host(nil), do: nil

  defp referrer_host(referrer),
    do: referrer |> URI.parse() |> Map.fetch!(:host) |> String.replace_prefix("www.", "")
end
