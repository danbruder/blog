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
end
