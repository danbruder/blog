defmodule BlogWeb.AnalyticsTracker do
  @moduledoc """
  `on_mount` hook that records a "page_view" event to `Blog.Analytics` for
  each connected LiveView mount and subsequent navigation, keyed by the
  client-supplied `sailor_id` (see `BlogWeb.PresenceTracker`) so views from
  the same browser tab can be correlated without cookies.
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:track, _params, _session, socket) do
    if connected?(socket) do
      connect_params = get_connect_params(socket)

      socket =
        socket
        |> assign(:analytics_session_id, connect_params["sailor_id"])
        |> assign(:analytics_referrer, connect_params["referrer"])
        |> assign(
          :analytics_country,
          socket |> BlogWeb.ClientInfo.ip() |> Blog.GeoIP.country_for_ip()
        )
        |> attach_hook(:track_page_view, :handle_params, &track_page_view/3)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  defp track_page_view(_params, uri, socket) do
    Blog.Analytics.track("page_view", %{
      path: URI.parse(uri).path,
      referrer: socket.assigns[:analytics_referrer],
      session_id: socket.assigns[:analytics_session_id],
      country: socket.assigns[:analytics_country]
    })

    {:cont, socket}
  end
end
