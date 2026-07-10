defmodule BlogWeb.AdminAuthTest do
  use BlogWeb.ConnCase, async: true

  test "GET /admin redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/admin")
    assert redirected_to(conn) == ~p"/admin/login"
  end

  test "POST /admin/login with wrong password re-renders with an error", %{conn: conn} do
    conn = post(conn, ~p"/admin/login", %{"password" => "nope"})
    assert conn.status == 401
    assert conn.resp_body =~ "Incorrect password"
  end

  test "POST /admin/login with the right password logs in and redirects to /admin", %{
    conn: conn
  } do
    conn =
      post(conn, ~p"/admin/login", %{"password" => Application.fetch_env!(:blog, :admin_password)})

    assert redirected_to(conn) == ~p"/admin"
    assert get_session(conn, :admin_authenticated) == true
  end
end
