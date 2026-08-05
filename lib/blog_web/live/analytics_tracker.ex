defmodule BlogWeb.AnalyticsTracker do
  @moduledoc """
  `on_mount` hook that records a "page_view" event to `Blog.Analytics` for
  each connected LiveView mount and subsequent navigation, keyed by the
  client-supplied `sailor_id` (see `BlogWeb.PresenceTracker`) so views from
  the same browser tab can be correlated without cookies.

  Skips tracking entirely for any browser that has ever logged in as admin
  (`session["admin_seen"]`, set by `BlogWeb.AdminSessionController` and
  never cleared -- see that module), so the admin's own visits never
  pollute their own analytics.
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:track, _params, session, socket) do
    if connected?(socket) and !session["admin_seen"] do
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
