defmodule BlogWeb.AdminSessionController do
  use BlogWeb, :controller

  def new(conn, _params) do
    render(conn, :new, error: nil, page_title: "Admin login")
  end

  def create(conn, %{"password" => password}) do
    if BlogWeb.AdminAuth.valid_password?(password) do
      conn
      |> put_session(:admin_authenticated, true)
      |> configure_session(renew: true)
      |> redirect(to: ~p"/admin")
    else
      conn
      |> put_status(:unauthorized)
      |> render(:new, error: "Incorrect password", page_title: "Admin login")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end
end
