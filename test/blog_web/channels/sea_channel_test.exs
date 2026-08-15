defmodule BlogWeb.SeaChannelTest do
  use BlogWeb.ChannelCase

  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  defp join_sea(sailor_id) do
    {:ok, socket} = connect(BlogWeb.UserSocket, %{}, connect_info: %{})
    subscribe_and_join(socket, "sea:ocean", %{"sailor_id" => sailor_id})
  end

  test "on join the client receives the current roster" do
    # Seed a reader into site presence directly.
    {:ok, _} =
      Presence.track(self(), PresenceTracker.topic(), "reader-key", %{
        country: "US",
        sailor_id: "reader-1",
        path: "/writing",
        joined_at: 0
      })

    {:ok, _reply, _socket} = join_sea("sailor-1")

    assert_push "roster", %{sailors: sailors}
    reader = Enum.find(sailors, &(&1.id == "reader-1"))
    assert reader.path == "/writing"
    assert reader.flag == "🇺🇸"
  end

  test "positions broadcast to other members but not the sender" do
    {:ok, _r1, socket1} = join_sea("sailor-1")

    push(socket1, "pos", %{"x" => 1.5, "z" => -2.0, "h" => 0.25})

    # assert_broadcast listens at the raw PubSub layer, so it observes the
    # broadcast regardless of the `_from` exclusion — this confirms the
    # payload that goes out is correct.
    assert_broadcast "pos", %{id: "sailor-1", x: 1.5, z: -2.0, h: 0.25}

    # refute_push checks what the client (socket1's own transport) actually
    # received — broadcast_from! must exclude the sender, so nothing arrives.
    refute_push "pos", %{id: "sailor-1"}
  end

  test "leaving broadcasts a gone event with the sailor's flag" do
    Process.flag(:trap_exit, true)

    {:ok, _} =
      Presence.track(self(), PresenceTracker.topic(), "reader-key", %{
        country: "US",
        sailor_id: "sailor-1",
        path: "/writing",
        joined_at: 0
      })

    {:ok, _r1, socket1} = join_sea("sailor-1")
    ref = leave(socket1)
    assert_reply ref, :ok
    assert_broadcast "gone", %{id: "sailor-1", flag: "🇺🇸"}
  end

  test "joining broadcasts an arrived event with the sailor's flag" do
    {:ok, _} =
      Presence.track(self(), PresenceTracker.topic(), "reader-key", %{
        country: "GB",
        sailor_id: "sailor-2",
        path: "/",
        joined_at: 0
      })

    {:ok, _r1, _socket1} = join_sea("sailor-1")
    {:ok, _r2, _socket2} = join_sea("sailor-2")

    # broadcast_from! is what excludes the joining sailor themself from this
    # event, the same mechanism already covered for "pos" above.
    assert_broadcast "arrived", %{id: "sailor-2", flag: "🇬🇧"}
  end

  test "a sailor with no presence entry arrives under a blank flag" do
    {:ok, _r1, _socket1} = join_sea("sailor-1")
    {:ok, _r2, _socket2} = join_sea("sailor-2")

    assert_broadcast "arrived", %{id: "sailor-2", flag: "🏳️"}
  end
end
