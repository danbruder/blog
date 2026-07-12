defmodule Blog.SandGame.Sim do
  @moduledoc """
  Pure falling-sand physics. `step/4` takes a byte-per-cell grid binary and
  returns the next grid binary. Cell access uses a transient `:atomics` array
  for O(1) reads/writes; randomness is derived deterministically from `:seed`
  so behaviour is reproducible and unit-testable.

  Element codes: 0 empty, 1 sand, 2 water, 3 stone, 4 wood, 5 fire.
  """

  @empty 0
  @sand 1
  @water 2
  @wood 4
  @fire 5

  @doc """
  Advance the grid one step.

  Options:
    * `:seed` (integer, default 0) — drives directional coin-flips.
    * `:p_ignite` (float 0..1, default 0.4) — chance fire lights adjacent wood.
    * `:p_burnout` (float 0..1, default 0.12) — chance a fire cell dies each tick.
  """
  def step(grid, w, h, opts \\ []) when is_binary(grid) do
    seed = Keyword.get(opts, :seed, 0)
    p_ignite = Keyword.get(opts, :p_ignite, 0.4)
    p_burnout = Keyword.get(opts, :p_burnout, 0.12)

    n = w * h
    cur = :atomics.new(n, signed: false)
    moved = :atomics.new(n, signed: false)
    load(cur, grid, n)

    # Scan bottom row upward so a falling particle isn't reprocessed after it
    # lands in an already-scanned row.
    for y <- (h - 1)..0//-1, x <- 0..(w - 1) do
      i = y * w + x

      if get(moved, i) == 0 do
        case get(cur, i) do
          @sand -> sand(cur, moved, x, y, w, h, seed)
          @water -> water(cur, moved, x, y, w, h, seed)
          @fire -> fire(cur, moved, x, y, w, h, seed, p_ignite, p_burnout)
          _ -> :ok
        end
      end
    end

    dump(cur, n)
  end

  # --- element rules --------------------------------------------------------

  defp sand(cur, moved, x, y, w, h, seed) do
    below = idx(x, y + 1, w)

    cond do
      y + 1 < h and get(cur, below) in [@empty, @water] ->
        swap(cur, moved, idx(x, y, w), below)

      true ->
        try_diagonal(cur, moved, x, y, w, h, seed, [@empty])
    end
  end

  defp water(cur, moved, x, y, w, h, seed) do
    below = idx(x, y + 1, w)

    cond do
      y + 1 < h and get(cur, below) == @empty ->
        swap(cur, moved, idx(x, y, w), below)

      try_diagonal(cur, moved, x, y, w, h, seed, [@empty]) == :moved ->
        :ok

      true ->
        try_side(cur, moved, x, y, w, seed)
    end
  end

  defp fire(cur, moved, x, y, w, h, seed, p_ignite, p_burnout) do
    i = idx(x, y, w)
    neighbors = orthogonal(x, y, w, h)

    doused? = Enum.any?(neighbors, fn j -> get(cur, j) == @water end)

    if doused? do
      set(cur, i, @empty)
    else
      Enum.each(neighbors, fn j ->
        if get(cur, j) == @wood and rand(seed, i, j) < p_ignite do
          set(cur, j, @fire)
          # Mark so freshly-lit wood doesn't also act as fire this same tick.
          set(moved, j, 1)
        end
      end)

      if rand(seed, i, i) < p_burnout, do: set(cur, i, @empty)
    end
  end

  # --- movement helpers -----------------------------------------------------

  defp try_diagonal(cur, moved, x, y, w, h, seed, targets) do
    if y + 1 < h do
      [d1, d2] = dirs(seed, idx(x, y, w))

      cond do
        try_move_to(cur, moved, idx(x, y, w), x + d1, y + 1, w, h, targets) == :moved -> :moved
        try_move_to(cur, moved, idx(x, y, w), x + d2, y + 1, w, h, targets) == :moved -> :moved
        true -> :stay
      end
    else
      :stay
    end
  end

  defp try_side(cur, moved, x, y, w, seed) do
    [d1, d2] = dirs(seed, idx(x, y, w))
    _ = try_move_to(cur, moved, idx(x, y, w), x + d1, y, w, :infinity, [@empty])
    _ = try_move_to(cur, moved, idx(x, y, w), x + d2, y, w, :infinity, [@empty])
    :ok
  end

  defp try_move_to(cur, moved, from, nx, ny, w, h, targets) do
    if nx >= 0 and nx < w and (h == :infinity or (ny >= 0 and ny < h)) do
      to = idx(nx, ny, w)

      if get(moved, to) == 0 and get(cur, to) in targets do
        swap(cur, moved, from, to)
        :moved
      else
        :stay
      end
    else
      :stay
    end
  end

  # Swap the contents of two cells and mark the destination as settled.
  defp swap(cur, moved, a, b) do
    va = get(cur, a)
    vb = get(cur, b)
    set(cur, a, vb)
    set(cur, b, va)
    set(moved, b, 1)
  end

  defp orthogonal(x, y, w, h) do
    for {dx, dy} <- [{0, -1}, {0, 1}, {-1, 0}, {1, 0}],
        nx = x + dx,
        ny = y + dy,
        nx >= 0 and nx < w and ny >= 0 and ny < h,
        do: idx(nx, ny, w)
  end

  # --- primitives -----------------------------------------------------------

  defp idx(x, y, w), do: y * w + x

  # :atomics is 1-indexed.
  defp get(ref, i), do: :atomics.get(ref, i + 1)
  defp set(ref, i, v), do: :atomics.put(ref, i + 1, v)

  defp load(ref, bin, n) do
    for i <- 0..(n - 1), do: :atomics.put(ref, i + 1, :binary.at(bin, i))
  end

  defp dump(ref, n) do
    0..(n - 1)
    |> Enum.map(fn i -> :atomics.get(ref, i + 1) end)
    |> :erlang.list_to_binary()
  end

  # Deterministic pseudo-random in [0.0, 1.0).
  defp rand(seed, a, b), do: :erlang.phash2({seed, a, b}) / 4_294_967_296

  # Deterministic [-1,1] or [1,-1] ordering for L/R tie-breaks.
  defp dirs(seed, i) do
    if rem(:erlang.phash2({seed, i}), 2) == 0, do: [-1, 1], else: [1, -1]
  end
end
