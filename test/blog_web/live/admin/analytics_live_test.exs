defmodule BlogWeb.Admin.AnalyticsLiveTest do
  use BlogWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Blog.Analytics

  defp admin_conn(conn) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:admin_authenticated, true)
  end

  test "GET /admin/analytics redirects to login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, ~p"/admin/analytics")
  end

  test "changing the range filter re-queries and shows different stats", %{conn: conn} do
    now = DateTime.utc_now()
    old = DateTime.add(now, -60, :day)

    Analytics.track("page_view", %{path: "/recent-page", session_id: "recent-sess"})
    :ok = Analytics.flush()

    {:ok, _cols, _rows} =
      Analytics.query(
        "INSERT INTO events (occurred_at_us, event_name, path, session_id) VALUES ($1, 'page_view', '/old-page', 'old-sess')",
        [DateTime.to_unix(old, :microsecond)]
      )

    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/analytics?range=7d")

    assert html =~ "/recent-page"
    refute html =~ "/old-page"

    html_all =
      view
      |> form("form", %{"range" => "all", "referrer" => ""})
      |> render_change()

    assert html_all =~ "/recent-page"
    assert html_all =~ "/old-page"
  end

  test "the range filter is reflected in the URL via push_patch", %{conn: conn} do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/analytics?range=7d")

    view
    |> form("form", %{"range" => "30d", "referrer" => ""})
    |> render_change()

    assert_patch(view, ~p"/admin/analytics?#{%{range: "30d", referrer: ""}}")
  end

  describe "click-to-filter" do
    test "clicking a top path filters the whole report to it, and reset clears it", %{
      conn: conn
    } do
      Analytics.track("page_view", %{path: "/foo", session_id: "sess-foo", country: "US"})
      Analytics.track("page_view", %{path: "/bar", session_id: "sess-bar", country: "CA"})
      :ok = Analytics.flush()

      {:ok, view, html} = live(admin_conn(conn), ~p"/admin/analytics?range=all")
      assert html =~ "/foo"
      assert html =~ "/bar"

      html =
        view
        |> element("button[phx-value-value='/foo']")
        |> render_click()

      assert_patch(view, ~p"/admin/analytics?#{%{range: "all", referrer: "", path: "/foo", country: ""}}")
      assert html =~ "/foo"
      refute html =~ "/bar"
      assert html =~ "Filtered by"

      html =
        view
        |> element("button", "Reset")
        |> render_click()

      assert_patch(view, ~p"/admin/analytics?#{%{range: "all", referrer: "", path: "", country: ""}}")
      assert html =~ "/foo"
      assert html =~ "/bar"
      refute html =~ "Filtered by"
    end

    test "clicking a top country filters the report to it", %{conn: conn} do
      Analytics.track("page_view", %{path: "/us-page", session_id: "sess-us", country: "US"})
      Analytics.track("page_view", %{path: "/ca-page", session_id: "sess-ca", country: "CA"})
      :ok = Analytics.flush()

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/analytics?range=all")

      html =
        view
        |> element("button[phx-value-value='CA']")
        |> render_click()

      assert html =~ "/ca-page"
      refute html =~ "/us-page"
    end

    test "clicking Direct in top referrers filters to sessions with no referrer", %{conn: conn} do
      Analytics.track("page_view", %{
        path: "/via-google",
        session_id: "sess-google",
        referrer: "https://google.com/search"
      })

      Analytics.track("page_view", %{path: "/direct-page", session_id: "sess-direct"})
      :ok = Analytics.flush()

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/analytics?range=all")

      html =
        view
        |> element("button[phx-value-value='direct']")
        |> render_click()

      assert html =~ "/direct-page"
      refute html =~ "/via-google"
    end
  end
end
