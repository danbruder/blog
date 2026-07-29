defmodule BlogWeb.SeaLive do
  @moduledoc """
  The Sea easter egg as a real route (`/sea`) instead of a client-side theme
  toggle. Routing to it and back gives the 3D scene a normal LiveView
  mount/unmount lifecycle, so the JS hook that boots three.js no longer races
  against a separate toggle button and `theme:changed` events — it just mounts
  when this page mounts.
  """

  use BlogWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: "Explore in 3D | Dan Bruder"),
     layout: {BlogWeb.Layouts, :sea}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="sea-root" phx-hook="SeaMode" phx-update="ignore" class="absolute inset-0"></div>
    """
  end
end
