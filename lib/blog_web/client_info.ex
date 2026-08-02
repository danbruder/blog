defmodule BlogWeb.ClientInfo do
  @moduledoc "Best-effort client IP extraction for a connected LiveView socket."

  import Phoenix.LiveView, only: [get_connect_info: 2]

  @doc "Returns the connecting client's IP as a string, or nil if it can't be determined."
  def ip(socket) do
    x_headers = get_connect_info(socket, :x_headers) || []

    case List.keyfind(x_headers, "x-forwarded-for", 0) do
      {_, value} ->
        value |> String.split(",") |> List.first() |> String.trim()

      nil ->
        case get_connect_info(socket, :peer_data) do
          %{address: address} -> address |> :inet.ntoa() |> to_string()
          _ -> nil
        end
    end
  end
end
