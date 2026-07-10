defmodule BlogWeb.AdminAuth do
  @moduledoc """
  Guards `/admin` routes behind the single admin password (session-based).
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :admin_authenticated) do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: "/admin/login")
      |> halt()
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    if session["admin_authenticated"] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/admin/login")}
    end
  end

  @doc "Constant-time check against the configured admin password."
  def valid_password?(password) when is_binary(password) do
    configured = Application.fetch_env!(:blog, :admin_password)
    Plug.Crypto.secure_compare(password, configured)
  end

  def valid_password?(_), do: false
end
