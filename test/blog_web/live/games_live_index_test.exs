defmodule BlogWeb.GamesLive.IndexTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "lists games and links Snake to /games/snake", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/games")

    assert html =~ "Games"
    assert html =~ "Snake"
    assert html =~ ~s|href="/games/snake"|
  end
end
