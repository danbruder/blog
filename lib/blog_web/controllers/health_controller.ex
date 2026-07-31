defmodule BlogWeb.HealthController do
  use BlogWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
