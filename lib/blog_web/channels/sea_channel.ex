defmodule BlogWeb.SeaChannel do
  @moduledoc """
  Real-time layer for the Sea easter egg. On join, a sailor receives the roster
  of everyone currently on the site (derived from the `site_presence` Presence,
  each entry reduced to id/path/flag) so reader-boats can be anchored at the
  right island. Sailors then broadcast their `{x, z, h}` position, which is
  fanned out to the other members and rendered as a live boat. Everything here
  is ephemeral — no storage.
  """

  use Phoenix.Channel

  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  @impl true
  def join("sea:ocean", %{"sailor_id" => sailor_id}, socket) do
    send(self(), :after_join)
    Phoenix.PubSub.subscribe(Blog.PubSub, PresenceTracker.topic())
    {:ok, assign(socket, :sailor_id, sailor_id)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    push(socket, "roster", %{sailors: roster()})
    {:noreply, socket}
  end

  # A reader joined/left/navigated: refresh the roster for this sailor.
  def handle_info(%{event: "presence_diff"}, socket) do
    push(socket, "roster", %{sailors: roster()})
    {:noreply, socket}
  end

  @impl true
  def handle_in("pos", %{"x" => x, "z" => z, "h" => h}, socket) do
    broadcast_from!(socket, "pos", %{id: socket.assigns.sailor_id, x: x, z: z, h: h})
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if id = socket.assigns[:sailor_id] do
      broadcast!(socket, "gone", %{id: id})
    end

    :ok
  end

  defp roster do
    PresenceTracker.topic()
    |> Presence.list()
    |> Enum.map(fn {key, %{metas: [meta | _]}} ->
      %{
        id: meta[:sailor_id] || key,
        path: meta[:path],
        flag: flag(meta[:country])
      }
    end)
  end

  # ISO-3166 alpha-2 -> regional-indicator flag emoji. Mirrors the admin
  # presence view's helper.
  defp flag(<<a, b>>) when a in ?A..?Z and b in ?A..?Z do
    <<127_397 + a::utf8, 127_397 + b::utf8>>
  end

  defp flag(_), do: "🏳️"
end
