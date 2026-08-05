defmodule BlogWeb.AdminSessionController do
  use BlogWeb, :controller

  def new(conn, _params) do
    render(conn, :new, error: nil, page_title: "Admin login")
  end

  def create(conn, %{"password" => password}) do
    if BlogWeb.AdminAuth.valid_password?(password) do
      conn
      |> put_session(:admin_authenticated, true)
      # Never cleared, including on logout (see `delete/2` below) -- this is
      # the durable "this browser is the admin" marker that
      # `BlogWeb.AnalyticsTracker` checks to exclude the admin's own
      # visits from analytics, regardless of whether they're currently
      # logged in.
      |> put_session(:admin_seen, true)
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
    |> delete_session(:admin_authenticated)
    |> redirect(to: ~p"/")
  end
end
