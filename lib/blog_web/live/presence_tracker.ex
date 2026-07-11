defmodule BlogWeb.PresenceTracker do
  @moduledoc """
  `on_mount` hook that tracks each connected public LiveView as a live
  viewer, tagged with a best-effort country lookup, under the
  #{inspect(__MODULE__)}.topic/0 presence topic. Also keeps a
  `:viewer_count` assign live-updated, for the site-wide viewer bubble.
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

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

      Phoenix.PubSub.subscribe(Blog.PubSub, @topic)
    end

    socket =
      socket
      |> assign(:viewer_count, viewer_count())
      |> attach_hook(:presence_viewer_count, :handle_info, &handle_presence_diff/2)

    {:cont, socket}
  end

  defp handle_presence_diff(%{event: "presence_diff"}, socket) do
    {:halt, assign(socket, :viewer_count, viewer_count())}
  end

  defp handle_presence_diff(_message, socket), do: {:cont, socket}

  defp viewer_count, do: @topic |> Presence.list() |> map_size()

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
