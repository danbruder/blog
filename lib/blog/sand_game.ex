defmodule Blog.SandGame do
  @moduledoc """
  A single, global, shared falling-sand sandbox for everyone viewing
  `/games/sand`. One authoritative GenServer owns a byte-per-cell grid,
  advances it via `Blog.SandGame.Sim` on each tick, and broadcasts the grid
  over `Blog.PubSub` on the `"sand"` topic. Painting from any viewer mutates
  the shared grid immediately. State is in-memory only.
  """
  use GenServer

  alias Blog.SandGame.Sim

  @topic "sand"
  @width 120
  @height 80
  @tick_ms 66
  @cells @width * @height

  # Public API ---------------------------------------------------------------

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def topic, do: @topic
  def dims, do: %{width: @width, height: @height}

  @doc "Register the caller as a viewer; returns {viewer_count, grid}."
  def join(pid), do: GenServer.call(__MODULE__, {:join, pid})

  def grid, do: GenServer.call(__MODULE__, :grid)

  @doc "Stamp `cells` (flat indices) with element `code` (0..5)."
  def paint(cells, code) when is_list(cells) and code in 0..5,
    do: GenServer.cast(__MODULE__, {:paint, cells, code})

  def clear, do: GenServer.call(__MODULE__, :clear)

  # GenServer ----------------------------------------------------------------

  @impl true
  def init(:ok) do
    :timer.send_interval(@tick_ms, :tick)
    {:ok, %{grid: empty_grid(), viewers: %{}, tick: 0}}
  end

  @impl true
  def handle_call({:join, pid}, _from, state) do
    ref = Process.monitor(pid)
    viewers = Map.put(state.viewers, ref, pid)
    new_state = %{state | viewers: viewers}
    {:reply, {map_size(viewers), state.grid}, new_state}
  end

  def handle_call(:grid, _from, state), do: {:reply, state.grid, state}

  def handle_call(:clear, _from, state) do
    new_state = %{state | grid: empty_grid()}
    broadcast(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:paint, cells, code}, state) do
    {:noreply, %{state | grid: stamp(state.grid, cells, code)}}
  end

  @impl true
  def handle_info(:tick, state) do
    # Only simulate while someone is watching and there's something to move.
    if map_size(state.viewers) == 0 do
      {:noreply, state}
    else
      tick = state.tick + 1
      next = Sim.step(state.grid, @width, @height, seed: tick)

      new_state = %{state | grid: next, tick: tick}
      # Broadcast only when the grid actually changed (idle boards stay quiet).
      if next != state.grid, do: broadcast(new_state)
      {:noreply, new_state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | viewers: Map.delete(state.viewers, ref)}}
  end

  # Helpers ------------------------------------------------------------------

  defp empty_grid, do: :binary.copy(<<0>>, @cells)

  # Apply a list of {index => code} stamps to the binary grid.
  defp stamp(grid, cells, code) do
    overrides = Map.new(cells, fn i -> {i, code} end)

    0..(@cells - 1)
    |> Enum.map(fn i -> Map.get(overrides, i, :binary.at(grid, i)) end)
    |> :erlang.list_to_binary()
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Blog.PubSub, @topic, {:sand_grid, Base.encode64(state.grid)})
  end
end
