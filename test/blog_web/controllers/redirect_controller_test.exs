defmodule BlogWeb.RedirectControllerTest do
  use BlogWeb.ConnCase, async: true

  test "GET /snake 301-redirects to /games/snake", %{conn: conn} do
    conn = get(conn, ~p"/snake")
    assert redirected_to(conn, 301) == "/games/snake"
  end
end
