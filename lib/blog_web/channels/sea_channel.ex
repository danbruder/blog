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

  `"drop_bottle"` / `"bottle_dropped"` / `"bottle_expired"` relay
  `Blog.SeaBottles`'s ephemeral messages-in-bottles: a sailor drops a short
  note, everyone in Sea mode sees it float until it auto-expires. Also not
  chat — one-way, capped length, no thread.
  """

  use Phoenix.Channel

  alias Blog.SeaBottles
  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  @impl true
  def join("sea:ocean", %{"sailor_id" => sailor_id}, socket) do
    send(self(), :after_join)
    Phoenix.PubSub.subscribe(Blog.PubSub, PresenceTracker.topic())
    Phoenix.PubSub.subscribe(Blog.PubSub, SeaBottles.topic())
    {:ok, assign(socket, :sailor_id, sailor_id)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    sailors = roster()
    push(socket, "roster", %{sailors: sailors})
    push(socket, "bottles", %{bottles: SeaBottles.list()})

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

  # Relayed straight through from Blog.SeaBottles's PubSub broadcast to every
  # member (including the dropper — simpler than special-casing "it's mine",
  # and it's how the dropper sees their own bottle land too).
  def handle_info({:bottle_dropped, bottle}, socket) do
    push(socket, "bottle_dropped", bottle)
    {:noreply, socket}
  end

  def handle_info({:bottle_expired, id}, socket) do
    push(socket, "bottle_expired", %{id: id})
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

  # Text length/blankness is validated in Blog.SeaBottles; a bottle that
  # comes out blank after trimming is silently dropped (no broadcast at
  # all), same as pressing "cancel" on the client's prompt.
  @impl true
  def handle_in("drop_bottle", %{"x" => x, "z" => z, "text" => text}, socket) do
    SeaBottles.drop(x, z, text, socket.assigns[:flag] || "🏳️")
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
