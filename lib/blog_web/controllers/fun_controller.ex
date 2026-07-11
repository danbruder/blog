defmodule BlogWeb.FunController do
  use BlogWeb, :controller

  def rpsb(conn, _params) do
    render(conn, :rpsb, page_title: "Rock Paper Scissors Boat")
  end
end
