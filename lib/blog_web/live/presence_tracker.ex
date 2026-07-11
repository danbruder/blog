defmodule BlogWeb.PresenceTracker do
  @moduledoc """
  `on_mount` hook that tracks each connected public LiveView as a live
  viewer, tagged with a best-effort country lookup, under the
  #{inspect(__MODULE__)}.topic/0 presence topic.
  """

  import Phoenix.LiveView

  alias BlogWeb.Presence

  @topic "site_presence"

  def topic, do: @topic

  def on_mount(:track, _params, _session, socket) do
    if connected?(socket) do
      country = socket |> client_ip() |> Blog.GeoIP.country_for_ip()

      {:ok, _ref} =
        Presence.track(self(), @topic, socket.id, %{
          country: country,
          joined_at: System.system_time(:second)
        })
    end

    {:cont, socket}
  end

  defp client_ip(socket) do
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
