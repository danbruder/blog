defmodule BlogWeb.SeaChannel do
  @moduledoc """
  Real-time layer for the Sea easter egg. On join, a sailor receives the roster
  of everyone currently on the site (derived from the `site_presence` Presence,
  each entry reduced to id/path/flag) so reader-boats can be anchored at the
  right island. Sailors then broadcast their `{x, z, h}` position, which is
  fanned out to the other members and rendered as a live boat. Everything here
  is ephemeral — no storage.

  Joining/leaving *this channel* (i.e. entering/exiting Sea mode, not just
  visiting the site) also fans out `"arrived"` / `"gone"` events so other
  sailors can show an arrival/departure toast. `"emote"` is a single,
  content-free wave gesture fanned out the same way as `"pos"` — deliberately
  not a chat channel.
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
    sailors = roster()
    push(socket, "roster", %{sailors: sailors})

    flag =
      case Enum.find(sailors, &(&1.id == socket.assigns.sailor_id)) do
        %{flag: flag} -> flag
        nil -> "🏳️"
      end

    # Told to everyone already sailing, not this sailor themself — stash the
    # flag in assigns so `terminate/2` can reuse it for the matching "gone".
    broadcast_from!(socket, "arrived", %{id: socket.assigns.sailor_id, flag: flag})
    {:noreply, assign(socket, :flag, flag)}
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

  # The wave/emote gesture — deliberately payload-free (no text, no
  # customization) so it can't grow into a chat channel by accident.
  @impl true
  def handle_in("emote", _params, socket) do
    broadcast_from!(socket, "emote", %{id: socket.assigns.sailor_id})
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if id = socket.assigns[:sailor_id] do
      broadcast!(socket, "gone", %{id: id, flag: socket.assigns[:flag] || "🏳️"})
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
