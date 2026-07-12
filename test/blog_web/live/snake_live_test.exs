defmodule BlogWeb.SnakeLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders the board and uses the game layout (no sidebar nav)", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/games/snake")

    # Game layout header
    assert html =~ "← Back"
    assert html =~ "Snake"
    # The board SVG is present
    assert html =~ "<svg"
    # The sidebar nav (Writing/Podcasts links) must NOT be on a game page
    refute html =~ ">Podcasts<"
  end
end
