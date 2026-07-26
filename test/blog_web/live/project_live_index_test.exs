defmodule BlogWeb.ProjectLive.IndexTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders a coming soon message", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/projects")

    assert html =~ "Projects"
    assert html =~ "Nothing shipped here yet"
  end
end
