defmodule BlogWeb.AnalyticsTrackerTest do
  use BlogWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Blog.Analytics

  test "records a page_view for an ordinary visitor", %{conn: conn} do
    sailor_id = "sailor_#{System.unique_integer([:positive])}"

    {:ok, _view, _html} =
      conn
      |> put_connect_params(%{"sailor_id" => sailor_id})
      |> live(~p"/writing")

    assert count_page_views(sailor_id) == 1
  end

  test "skips tracking for a browser that has ever logged in as admin", %{conn: conn} do
    sailor_id = "sailor_#{System.unique_integer([:positive])}"

    {:ok, _view, _html} =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:admin_seen, true)
      |> put_connect_params(%{"sailor_id" => sailor_id})
      |> live(~p"/writing")

    assert count_page_views(sailor_id) == 0
  end

  defp count_page_views(sailor_id) do
    :ok = Analytics.flush()

    {:ok, _columns, rows} =
      Analytics.query("SELECT COUNT(*) FROM events WHERE session_id = $1", [sailor_id])

    [[count]] = rows
    count
  end
end
