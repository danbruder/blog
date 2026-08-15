defmodule Blog.SeaBottlesTest do
  use ExUnit.Case, async: false

  alias Blog.SeaBottles

  setup do
    Phoenix.PubSub.subscribe(Blog.PubSub, SeaBottles.topic())
    :ok
  end

  test "drop/5 broadcasts the bottle and adds it to list/0" do
    SeaBottles.drop(1.0, 2.0, "hello sailors", "🇺🇸")

    assert_receive {:bottle_dropped, bottle}
    assert bottle.x == 1.0
    assert bottle.z == 2.0
    assert bottle.text == "hello sailors"
    assert bottle.flag == "🇺🇸"

    assert Enum.any?(SeaBottles.list(), &(&1.id == bottle.id))
  end

  test "drop/5 trims and caps text to 80 characters" do
    padded = "  " <> String.duplicate("x", 90) <> "  "
    SeaBottles.drop(0, 0, padded)

    assert_receive {:bottle_dropped, bottle}
    assert bottle.text == String.duplicate("x", 80)
  end

  test "drop/5 is a no-op for blank text" do
    SeaBottles.drop(0, 0, "   ")
    refute_receive {:bottle_dropped, _}, 50
  end

  test "a bottle expires and is removed from list/0 after its ttl" do
    SeaBottles.drop(3.0, 4.0, "gone soon", "🏳️", 10)

    assert_receive {:bottle_dropped, bottle}
    assert_receive {:bottle_expired, id}, 200
    assert id == bottle.id
    refute Enum.any?(SeaBottles.list(), &(&1.id == id))
  end
end
