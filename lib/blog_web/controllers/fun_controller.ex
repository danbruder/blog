defmodule BlogWeb.FunController do
  use BlogWeb, :controller

  def rpsb(conn, _params) do
    render(conn, :rpsb, page_title: "Rock Paper Scissors Boat")
  end

  def snake(conn, _params) do
    render(conn, :snake, page_title: "Snake")
  end
end
