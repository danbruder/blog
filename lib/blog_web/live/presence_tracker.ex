defmodule BlogWeb.PresenceTracker do
  @moduledoc """
  `on_mount` hook that tracks each connected public LiveView as a live
  viewer under the #{inspect(__MODULE__)}.topic/0 presence topic. The meta
  carries a best-effort `country`, the client-supplied `sailor_id` (stable per
  browser tab, used to correlate a reader's anchored boat with their live boat
  in the Sea easter egg), and the current `path` (which island the viewer sits
  at), kept up to date as they navigate. Also keeps a live `:viewer_count`
  assign for the site-wide viewer bubble.
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  alias BlogWeb.Presence

  @topic "site_presence"

  def topic, do: @topic

  def on_mount(:track, _params, _session, socket) do
    if connected?(socket) do
      country = socket |> client_ip() |> Blog.GeoIP.country_for_ip()
      sailor_id = get_connect_params(socket)["sailor_id"]

      {:ok, _ref} =
        Presence.track(self(), @topic, socket.id, %{
          country: country,
          sailor_id: sailor_id,
          path: nil,
          joined_at: System.system_time(:second)
        })

      Phoenix.PubSub.subscribe(Blog.PubSub, @topic)
    end

    socket =
      socket
      |> assign(:viewer_count, viewer_count())
      |> attach_hook(:presence_viewer_count, :handle_info, &handle_presence_diff/2)
      |> attach_hook(:presence_path, :handle_params, &track_path/3)

    {:cont, socket}
  end

  defp track_path(_params, uri, socket) do
    if connected?(socket) do
      path = URI.parse(uri).path

      Presence.update(self(), @topic, socket.id, fn meta ->
        Map.put(meta, :path, path)
      end)
    end

    {:cont, socket}
  end

  defp handle_presence_diff(%{event: "presence_diff"}, socket) do
    {:halt, assign(socket, :viewer_count, viewer_count())}
  end

  defp handle_presence_diff(_message, socket), do: {:cont, socket}

  defp viewer_count, do: @topic |> Presence.list() |> map_size()

  defp client_ip(socket), do: BlogWeb.ClientInfo.ip(socket)
end
