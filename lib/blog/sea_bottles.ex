defmodule Blog.SeaBottles do
  @moduledoc """
  Ephemeral "message in a bottle" notes for the Sea easter egg. A sailor can
  drop a short note at their current position; every sailor in Sea mode sees
  it floating there until it expires on its own, then it's gone for good.

  Deliberately not chat: one-way (no replies, no threading), short (capped
  length), auto-expiring, and never written to disk — a small global
  GenServer holds the current set in memory and broadcasts drops/expiries
  over `Blog.PubSub` on `topic/0`, the same ephemeral pattern `Blog.SandGame`
  and `Blog.SnakeGame` use for their shared state.
  """
  use GenServer

  @topic "sea:bottles"
  @max_length 80
  @ttl_ms 5 * 60 * 1_000
  # Bounds memory/broadcast volume regardless of who's dropping bottles (no
  # auth on this channel) -- oldest active bottle is evicted early to make
  # room rather than letting the set grow without limit.
  @max_bottles 30

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def topic, do: @topic

  @doc "Returns every currently-active bottle."
  def list, do: GenServer.call(__MODULE__, :list)

  @doc """
  Drops a bottle at `{x, z}` carrying `text` (trimmed and capped to
  #{@max_length} chars). A blank `text` is a no-op. Broadcasts
  `{:bottle_dropped, bottle}` on `topic/0` and schedules its own
  `{:bottle_expired, id}` broadcast after `ttl_ms`.
  """
  def drop(x, z, text, flag \\ "🏳️", ttl_ms \\ @ttl_ms) do
    GenServer.cast(__MODULE__, {:drop, x, z, text, flag, ttl_ms})
  end

  @impl true
  def init(:ok), do: {:ok, %{bottles: %{}}}

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.bottles), state}
  end

  @impl true
  def handle_cast({:drop, x, z, text, flag, ttl_ms}, state) do
    text = text |> to_string() |> String.trim() |> String.slice(0, @max_length)

    if text == "" do
      {:noreply, state}
    else
      id = System.unique_integer([:positive, :monotonic])
      bottle = %{id: id, x: x, z: z, text: text, flag: flag}
      Process.send_after(self(), {:expire, id}, ttl_ms)

      bottles = state.bottles |> evict_oldest_if_full() |> Map.put(id, bottle)
      broadcast({:bottle_dropped, bottle})
      {:noreply, %{state | bottles: bottles}}
    end
  end

  @impl true
  def handle_info({:expire, id}, state) do
    if Map.has_key?(state.bottles, id) do
      broadcast({:bottle_expired, id})
      {:noreply, %{state | bottles: Map.delete(state.bottles, id)}}
    else
      # Already gone (e.g. evicted early to make room) -- nothing to do.
      {:noreply, state}
    end
  end

  defp evict_oldest_if_full(bottles) when map_size(bottles) < @max_bottles, do: bottles

  defp evict_oldest_if_full(bottles) do
    {oldest_id, _} = Enum.min_by(bottles, fn {id, _} -> id end)
    broadcast({:bottle_expired, oldest_id})
    Map.delete(bottles, oldest_id)
  end

  defp broadcast(msg), do: Phoenix.PubSub.broadcast(Blog.PubSub, @topic, msg)
end
