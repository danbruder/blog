defmodule BlogWeb.RedirectController do
  @moduledoc """
  Static path redirects. `/snake` 301s to its new home under `/games/snake`.
  """
  use BlogWeb, :controller

  def snake(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: ~p"/games/snake")
    |> halt()
  end
end
