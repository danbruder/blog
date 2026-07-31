defmodule BlogWeb.HealthControllerTest do
  use BlogWeb.ConnCase, async: true

  test "GET /healthz returns ok status", %{conn: conn} do
    conn = get(conn, ~p"/healthz")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
