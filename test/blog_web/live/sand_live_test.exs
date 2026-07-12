defmodule BlogWeb.SandLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders the palette, clear, and canvas, in the game layout", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/games/sand")

    assert html =~ "← Back"
    assert html =~ "Sand"
    assert html =~ ~s(phx-hook="SandCanvas")
    assert html =~ "Clear"
    assert html =~ "Water"
    # Not the sidebar layout
    refute html =~ ">Podcasts<"
  end

  test "clear event empties the shared grid", %{conn: conn} do
    Blog.SandGame.paint([0, 1, 2], 1)
    {:ok, view, _html} = live(conn, ~p"/games/sand")
    render_click(view, "clear")
    assert Blog.SandGame.grid() == :binary.copy(<<0>>, byte_size(Blog.SandGame.grid()))
  end
end
