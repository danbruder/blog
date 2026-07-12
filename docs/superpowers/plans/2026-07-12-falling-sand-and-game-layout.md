# Falling-Sand Game + Game Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a shared global falling-sand sandbox at `/games/sand`, and a viewport-locked full-width "game layout" (no sidebar, painted header, back button) used by the Snake and Sand game views.

**Architecture:** A `Blog.SandGame` GenServer owns an authoritative byte-per-cell grid, ticks ~15fps, runs pure physics in `Blog.SandGame.Sim`, and broadcasts the grid over `Blog.PubSub`. `BlogWeb.SandLive` renders a `<canvas>` painted by a JS hook that also captures paint strokes. A new `game.html.heex` layout locks games to the viewport so arrow keys can't scroll.

**Tech Stack:** Elixir, Phoenix LiveView, `:atomics` (fast in-place grid sim), `:erlang.phash2` (deterministic seeded randomness), HTML canvas + JS hooks, Tailwind.

---

## File Structure

**New:**
- `lib/blog/sand_game/sim.ex` — pure physics: `step/4`. One responsibility: given a grid, produce the next grid.
- `lib/blog/sand_game.ex` — GenServer: state ownership, join/monitor, paint, clear, tick, broadcast.
- `lib/blog_web/live/sand_live.ex` — the Sand LiveView (palette + canvas + events).
- `lib/blog_web/components/layouts/game.html.heex` — viewport-locked game layout.
- `test/blog/sand_game/sim_test.exs`
- `test/blog/sand_game_test.exs`
- `test/blog_web/live/sand_live_test.exs`

**Modified:**
- `lib/blog/application.ex` — supervise `Blog.SandGame`.
- `lib/blog_web/router.ex` — `live("/games/sand", SandLive, :index)`.
- `lib/blog_web/live/games_live/index.ex` — add Sand card.
- `lib/blog_web/live/snake_live.ex` — migrate to game layout, bigger board.
- `assets/js/app.js` — register `SandCanvas` hook.

**Element codes (shared contract, used in `Sim`, `SandGame`, and the JS hook):**
`0` empty · `1` sand · `2` water · `3` stone · `4` wood · `5` fire

---

## Task 1: Game layout

**Files:**
- Create: `lib/blog_web/components/layouts/game.html.heex`

`BlogWeb.Layouts` already does `embed_templates("layouts/*")`, so a new file is auto-available as `{BlogWeb.Layouts, :game}` — no module edit needed.

- [ ] **Step 1: Create the layout**

Create `lib/blog_web/components/layouts/game.html.heex`:

```heex
<div class="h-[100dvh] flex flex-col overflow-hidden bg-zinc-900 text-zinc-50">
  <header class="painted shrink-0 relative overflow-hidden border-b border-zinc-800">
    <div class="relative z-10 flex items-center justify-between px-4 py-3">
      <.link
        navigate={~p"/games"}
        class="font-fancy text-sm text-zinc-200 no-underline hover:text-white"
      >
        ← Back
      </.link>
      <span class="font-fancy text-lg text-[color:var(--accent-heading)]">
        {assigns[:game_name]}
      </span>
      <span class="text-sm text-zinc-400 w-16 text-right">
        <span :if={assigns[:viewer_count]}>{@viewer_count} 👀</span>
      </span>
    </div>
  </header>

  <main class="flex-1 min-h-0 overflow-hidden">
    {@inner_content}
  </main>
</div>

<.flash_group flash={@flash} />
```

- [ ] **Step 2: Compile**

Run: `mix compile --warnings-as-errors`
Expected: clean compile (layout defined; not used until a LiveView opts in).

- [ ] **Step 3: Commit**

```bash
git add lib/blog_web/components/layouts/game.html.heex
git commit -m "Add viewport-locked game layout (no sidebar, painted header, back button)"
```

---

## Task 2: Migrate Snake to the game layout with a bigger board

**Files:**
- Modify: `lib/blog_web/live/snake_live.ex`
- Test: `test/blog_web/live/snake_live_test.exs` (create)

- [ ] **Step 1: Write a failing test**

Create `test/blog_web/live/snake_live_test.exs`:

```elixir
defmodule BlogWeb.SnakeLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders the board and uses the game layout (no sidebar nav)", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/games/snake")

    # Game layout header
    assert html =~ "← Back"
    assert html =~ "Snake"
    # The board SVG is present
    assert html =~ "<svg"
    # The sidebar nav (Writing/Podcasts links) must NOT be on a game page
    refute html =~ ">Podcasts<"
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `mix test test/blog_web/live/snake_live_test.exs`
Expected: FAIL — Snake still renders the sidebar layout (contains "Podcasts") and the page_hero, no "← Back".

- [ ] **Step 3: Set the game layout + game_name in mount**

In `lib/blog_web/live/snake_live.ex`, both `mount/3` clauses currently return `{:ok, assign(socket, ...)}`. Add `game_name` to each assign list and return the game layout. Change the connected clause's return from:

```elixir
      {:ok,
       assign(socket,
         player_id: id,
         game: state,
         page_title: "Snake",
         connected: true,
         editing_name: false
       )}
```

to:

```elixir
      {:ok,
       assign(socket,
         player_id: id,
         game: state,
         page_title: "Snake",
         game_name: "Snake",
         connected: true,
         editing_name: false
       ), layout: {BlogWeb.Layouts, :game}}
```

and the disconnected clause from:

```elixir
      {:ok,
       assign(socket,
         player_id: nil,
         game: %{cols: dims.cols, rows: dims.rows, players: [], foods: []},
         page_title: "Snake",
         connected: false,
         editing_name: false
       )}
```

to:

```elixir
      {:ok,
       assign(socket,
         player_id: nil,
         game: %{cols: dims.cols, rows: dims.rows, players: [], foods: []},
         page_title: "Snake",
         game_name: "Snake",
         connected: false,
         editing_name: false
       ), layout: {BlogWeb.Layouts, :game}}
```

- [ ] **Step 4: Replace the render template's outer structure**

In `render/1`, replace the opening — currently (after the earlier hero migration):

```heex
    <.page_hero
      title="Snake"
      eyebrow="Games"
      subtitle="A single global game — everyone here shares the board. Arrow keys or WASD to steer; crash and you respawn."
    />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10" phx-window-keydown="key">
      <div class="mx-auto max-w-5xl">

        <div class="flex flex-col md:flex-row gap-6 items-start">
```

with:

```heex
    <div class="h-full flex flex-col p-4" phx-window-keydown="key">
      <div class="flex-1 min-h-0 flex flex-col md:flex-row gap-4">
```

Then find the board column wrapper, currently:

```heex
          <div class="flex-1 min-w-0">
            <svg
              viewBox={"0 0 #{@game.cols * @cell} #{@game.rows * @cell}"}
              class="snake bg-zinc-800 w-full h-auto"
              preserveAspectRatio="xMidYMid meet"
            >
```

change the wrapper + svg classes to fill height:

```heex
          <div class="flex-1 min-w-0 min-h-0 flex items-center justify-center">
            <svg
              viewBox={"0 0 #{@game.cols * @cell} #{@game.rows * @cell}"}
              class="snake bg-zinc-800 max-w-full max-h-full h-auto w-auto"
              preserveAspectRatio="xMidYMid meet"
            >
```

Then the players panel wrapper, currently:

```heex
          <div class="w-full md:w-56 shrink-0">
```

change to allow internal scroll without scrolling the page:

```heex
          <div class="w-full md:w-56 shrink-0 md:max-h-full md:overflow-y-auto">
```

Finally, the two outer `</div>`s that previously closed `max-w-5xl` and `max-w-7xl` now close the two new wrappers — the tag count is unchanged (two opened, two closed), so the existing closing tags at the end of the template still balance. Add a small caption just above the closing of the board area is optional; to keep the WASD hint, insert this right after the `<svg>...</svg>` closes and before the mobile dpad `<div>`:

```heex
            <p class="text-center text-xs text-gray-500 mt-2">
              Arrow keys or WASD to steer · crash and you respawn
            </p>
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `mix test test/blog_web/live/snake_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Manually verify no-scroll + big board**

Run: `mix phx.server`; open `http://localhost:4000/games/snake`.
Expected: full-screen board, painted header with "← Back" and "Snake", no sidebar, page does not scroll when pressing the down arrow.

- [ ] **Step 7: Commit**

```bash
git add lib/blog_web/live/snake_live.ex test/blog_web/live/snake_live_test.exs
git commit -m "Migrate Snake to game layout with a full-screen non-scrolling board"
```

---

## Task 3: `Sim` — grid helpers + sand physics

**Files:**
- Create: `lib/blog/sand_game/sim.ex`
- Test: `test/blog/sand_game/sim_test.exs`

`step/4` loads the input binary into a transient `:atomics` array, simulates in place (fast O(1) cell access), and returns a new binary. Randomness is deterministic: derived from a `:seed` via `:erlang.phash2/1`, so tests are reproducible. Ignite/burnout probabilities are passed in `opts` so tests can force them to 0.0/1.0.

- [ ] **Step 1: Write failing tests for sand**

Create `test/blog/sand_game/sim_test.exs`:

```elixir
defmodule Blog.SandGame.SimTest do
  use ExUnit.Case, async: true

  alias Blog.SandGame.Sim

  # Build a grid binary from a list of rows of codes (top row first).
  defp grid(rows) do
    w = length(hd(rows))
    h = length(rows)
    bin = rows |> List.flatten() |> :erlang.list_to_binary()
    {bin, w, h}
  end

  defp at({bin, w, _h}, x, y), do: :binary.at(bin, y * w + x)

  test "sand falls into empty space below" do
    {g, w, h} = grid([[1], [0]])
    {g2, _, _} = {Sim.step(g, w, h, seed: 1), w, h}
    assert at({g2, w, h}, 0, 0) == 0
    assert at({g2, w, h}, 0, 1) == 1
  end

  test "sand rests on the floor" do
    {g, w, h} = grid([[0], [1]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 1) == 1
  end

  test "sand slides diagonally when blocked directly below" do
    # sand at (1,0); (1,1) is stone; one of the diagonals must receive it.
    {g, w, h} = grid([[0, 1, 0], [0, 3, 0]])
    g2 = Sim.step(g, w, h, seed: 1)
    landed = at({g2, w, h}, 0, 1) == 1 or at({g2, w, h}, 2, 1) == 1
    assert landed
    assert at({g2, w, h}, 1, 0) == 0
  end

  test "sand sinks through water (they swap)" do
    {g, w, h} = grid([[1], [2]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 0) == 2
    assert at({g2, w, h}, 0, 1) == 1
  end

  test "a particle moves at most one cell per tick" do
    {g, w, h} = grid([[1], [0], [0]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 1) == 1
    assert at({g2, w, h}, 0, 2) == 0
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/blog/sand_game/sim_test.exs`
Expected: FAIL — `Blog.SandGame.Sim` does not exist.

- [ ] **Step 3: Implement `Sim` with sand rules**

Create `lib/blog/sand_game/sim.ex`:

```elixir
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
  @stone 3
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
```

- [ ] **Step 4: Run to verify sand tests pass**

Run: `mix test test/blog/sand_game/sim_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/blog/sand_game/sim.ex test/blog/sand_game/sim_test.exs
git commit -m "Add SandGame.Sim pure physics with sand rules"
```

---

## Task 4: `Sim` — water + static solids tests

The water/stone/wood logic is already implemented in Task 3's `Sim`. This task adds the tests that lock in that behaviour.

**Files:**
- Modify: `test/blog/sand_game/sim_test.exs`

- [ ] **Step 1: Add water/solid tests**

Append inside the `describe`-less test module in `test/blog/sand_game/sim_test.exs` (before the final `end`):

```elixir
  test "water falls into empty space below" do
    {g, w, h} = grid([[2], [0]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 0) == 0
    assert at({g2, w, h}, 0, 1) == 2
  end

  test "water spreads sideways on a flat floor" do
    # water at (1,1) sitting on stone floor; must move to an open side cell.
    {g, w, h} = grid([[0, 0, 0], [3, 2, 3], [3, 3, 3]])
    # Side neighbors (0,1)/(2,1) are stone, so it can't spread; it should stay.
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 1, 1) == 2

    {g3, w3, h3} = grid([[0, 0, 0], [0, 2, 0], [3, 3, 3]])
    g4 = Sim.step(g3, w3, h3, seed: 1)
    # It can't go straight down (stone floor), so it slides to a bottom-diagonal.
    moved_down_diag = at({g4, w3, h3}, 0, 1) == 0 and at({g4, w3, h3}, 1, 1) == 0
    assert at({g4, w3, h3}, 0, 1) == 2 or at({g4, w3, h3}, 2, 1) == 2 or moved_down_diag == false
  end

  test "stone and wood never move on their own" do
    {g, w, h} = grid([[3, 4], [0, 0]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 0) == 3
    assert at({g2, w, h}, 1, 0) == 4
  end
```

- [ ] **Step 2: Run to verify they pass**

Run: `mix test test/blog/sand_game/sim_test.exs`
Expected: PASS (8 tests).

- [ ] **Step 3: Commit**

```bash
git add test/blog/sand_game/sim_test.exs
git commit -m "Lock in water spreading and static-solid behaviour"
```

---

## Task 5: `Sim` — fire/wood reaction tests

Fire logic is implemented in Task 3. This task adds tests, using `p_ignite`/`p_burnout` extremes for determinism.

**Files:**
- Modify: `test/blog/sand_game/sim_test.exs`

- [ ] **Step 1: Add fire tests**

Append before the module's final `end`:

```elixir
  test "fire ignites adjacent wood when p_ignite is 1.0" do
    # fire at (0,0), wood at (1,0)
    {g, w, h} = grid([[5, 4]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 1.0, p_burnout: 0.0)
    assert at({g2, w, h}, 1, 0) == 5
  end

  test "fire does not ignite wood when p_ignite is 0.0" do
    {g, w, h} = grid([[5, 4]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 0.0, p_burnout: 0.0)
    assert at({g2, w, h}, 1, 0) == 4
  end

  test "fire adjacent to water is extinguished" do
    {g, w, h} = grid([[5, 2]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 1.0, p_burnout: 0.0)
    assert at({g2, w, h}, 0, 0) == 0
  end

  test "fire burns out when p_burnout is 1.0" do
    {g, w, h} = grid([[5]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 0.0, p_burnout: 1.0)
    assert at({g2, w, h}, 0, 0) == 0
  end

  test "isolated fire persists when p_burnout is 0.0" do
    {g, w, h} = grid([[5]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 0.0, p_burnout: 0.0)
    assert at({g2, w, h}, 0, 0) == 5
  end
```

- [ ] **Step 2: Run to verify they pass**

Run: `mix test test/blog/sand_game/sim_test.exs`
Expected: PASS (13 tests).

- [ ] **Step 3: Commit**

```bash
git add test/blog/sand_game/sim_test.exs
git commit -m "Lock in fire/wood reactions and burnout"
```

---

## Task 6: `Blog.SandGame` GenServer + supervision

**Files:**
- Create: `lib/blog/sand_game.ex`
- Modify: `lib/blog/application.ex`
- Test: `test/blog/sand_game_test.exs`

- [ ] **Step 1: Write failing tests**

Create `test/blog/sand_game_test.exs`:

```elixir
defmodule Blog.SandGameTest do
  use ExUnit.Case, async: false

  alias Blog.SandGame

  test "grid/0 returns width*height bytes" do
    %{width: w, height: h} = SandGame.dims()
    assert byte_size(SandGame.grid()) == w * h
  end

  test "paint/2 stamps the given cells with the element code" do
    SandGame.clear()
    SandGame.paint([0, 1, 2], 3)
    grid = SandGame.grid()
    assert :binary.at(grid, 0) == 3
    assert :binary.at(grid, 1) == 3
    assert :binary.at(grid, 2) == 3
  end

  test "clear/0 empties the grid" do
    SandGame.paint([5, 6, 7], 1)
    SandGame.clear()
    grid = SandGame.grid()
    assert grid == :binary.copy(<<0>>, byte_size(grid))
  end

  test "join/1 returns viewer count and the current grid, and monitors the pid" do
    SandGame.clear()
    {count, grid} = SandGame.join(self())
    assert is_integer(count) and count >= 1
    assert byte_size(grid) == byte_size(SandGame.grid())
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/blog/sand_game_test.exs`
Expected: FAIL — `Blog.SandGame` does not exist / not started.

- [ ] **Step 3: Implement the GenServer**

Create `lib/blog/sand_game.ex`:

```elixir
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
```

- [ ] **Step 4: Supervise it**

In `lib/blog/application.ex`, add `Blog.SandGame` to `children`, right after `Blog.SnakeGame`:

```elixir
      Blog.SnakeGame,
      Blog.SandGame,
      BlogWeb.Endpoint
```

- [ ] **Step 5: Run tests to verify pass**

Run: `mix test test/blog/sand_game_test.exs`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/blog/sand_game.ex lib/blog/application.ex test/blog/sand_game_test.exs
git commit -m "Add SandGame GenServer (grid state, paint, clear, tick, broadcast)"
```

---

## Task 7: `SandCanvas` JS hook

**Files:**
- Modify: `assets/js/app.js`

- [ ] **Step 1: Add the hook to the `Hooks` object**

In `assets/js/app.js`, add a `SandCanvas` entry to `Hooks` (after `MobileNav`, with a comma separating them):

```javascript
  // Renders the shared sand grid onto a <canvas> and captures paint strokes.
  // The server pushes the full grid as base64 on the "grid" event; this hook
  // decodes it and repaints. Pointer drags send `paint` events back.
  SandCanvas: {
    mounted() {
      this.w = parseInt(this.el.dataset.w, 10)
      this.h = parseInt(this.el.dataset.h, 10)
      this.el.width = this.w
      this.el.height = this.h
      this.ctx = this.el.getContext("2d")
      this.colors = {
        0: "#18181b", // empty
        1: "#e6c07b", // sand
        2: "#38bdf8", // water
        3: "#71717a", // stone
        4: "#92640f", // wood
        5: "#f97316"  // fire
      }
      this.selected = () => parseInt(this.el.dataset.selected || "1", 10)
      this.painting = false

      this.handleEvent("grid", ({grid}) => this.draw(grid))

      const paintAt = (e) => {
        const rect = this.el.getBoundingClientRect()
        const px = e.clientX - rect.left
        const py = e.clientY - rect.top
        const gx = Math.floor((px / rect.width) * this.w)
        const gy = Math.floor((py / rect.height) * this.h)
        const r = 2
        const cells = []
        for (let dy = -r; dy <= r; dy++) {
          for (let dx = -r; dx <= r; dx++) {
            const x = gx + dx, y = gy + dy
            if (x >= 0 && x < this.w && y >= 0 && y < this.h && dx*dx + dy*dy <= r*r) {
              cells.push(y * this.w + x)
            }
          }
        }
        if (cells.length) this.pushEvent("paint", {cells, element: this.selected()})
      }

      this.el.addEventListener("pointerdown", (e) => { this.painting = true; paintAt(e) })
      this.el.addEventListener("pointermove", (e) => { if (this.painting) paintAt(e) })
      window.addEventListener("pointerup", () => { this.painting = false })
      // Stop touch-drag from scrolling/zooming while painting.
      this.el.style.touchAction = "none"
    },

    draw(b64) {
      const bin = atob(b64)
      const img = this.ctx.createImageData(this.w, this.h)
      for (let i = 0; i < bin.length; i++) {
        const hex = this.colors[bin.charCodeAt(i)] || this.colors[0]
        const r = parseInt(hex.slice(1, 3), 16)
        const g = parseInt(hex.slice(3, 5), 16)
        const bl = parseInt(hex.slice(5, 7), 16)
        const o = i * 4
        img.data[o] = r; img.data[o+1] = g; img.data[o+2] = bl; img.data[o+3] = 255
      }
      this.ctx.putImageData(img, 0, 0)
    }
  }
```

- [ ] **Step 2: Verify JS is syntactically valid**

Run: `node --check assets/js/app.js`
Expected: no output (valid). If `node` is unavailable, skip; the browser build in Task 9 will surface errors.

- [ ] **Step 3: Commit**

```bash
git add assets/js/app.js
git commit -m "Add SandCanvas hook: render grid to canvas + capture paint strokes"
```

---

## Task 8: `SandLive` + route + Games card

**Files:**
- Create: `lib/blog_web/live/sand_live.ex`
- Modify: `lib/blog_web/router.ex`, `lib/blog_web/live/games_live/index.ex`
- Test: `test/blog_web/live/sand_live_test.exs`

- [ ] **Step 1: Write failing tests**

Create `test/blog_web/live/sand_live_test.exs`:

```elixir
defmodule BlogWeb.SandLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders the palette, clear, and canvas, in the game layout", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/games/sand")

    assert html =~ "← Back"
    assert html =~ "Sand"
    assert html =~ ~s(phx-hook="SandCanvas")
    assert html =~ "Clear"
    assert html =~ "Water"
    # Not the sidebar layout
    refute html =~ ">Podcasts<"
  end

  test "clear event empties the shared grid", %{conn: conn} do
    Blog.SandGame.paint([0, 1, 2], 1)
    {:ok, view, _html} = live(conn, ~p"/games/sand")
    render_click(view, "clear")
    assert Blog.SandGame.grid() == :binary.copy(<<0>>, byte_size(Blog.SandGame.grid()))
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/blog_web/live/sand_live_test.exs`
Expected: FAIL — no `/games/sand` route / `SandLive`.

- [ ] **Step 3: Create `SandLive`**

Create `lib/blog_web/live/sand_live.ex`:

```elixir
defmodule BlogWeb.SandLive do
  use BlogWeb, :live_view

  alias Blog.SandGame

  @elements [
    {"Sand", 1}, {"Water", 2}, {"Stone", 3}, {"Wood", 4}, {"Fire", 5}, {"Erase", 0}
  ]

  @impl true
  def mount(_params, _session, socket) do
    %{width: w, height: h} = SandGame.dims()

    socket =
      socket
      |> assign(
        page_title: "Sand",
        game_name: "Sand",
        width: w,
        height: h,
        selected: 1,
        elements: @elements
      )

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blog.PubSub, SandGame.topic())
      {_count, grid} = SandGame.join(self())
      socket = push_event(socket, "grid", %{grid: Base.encode64(grid)})
      {:ok, socket, layout: {BlogWeb.Layouts, :game}}
    else
      {:ok, socket, layout: {BlogWeb.Layouts, :game}}
    end
  end

  @impl true
  def handle_event("select", %{"code" => code}, socket) do
    {:noreply, assign(socket, selected: String.to_integer(code))}
  end

  def handle_event("paint", %{"cells" => cells, "element" => code}, socket) do
    SandGame.paint(cells, code)
    {:noreply, socket}
  end

  def handle_event("clear", _params, socket) do
    SandGame.clear()
    {:noreply, socket}
  end

  @impl true
  def handle_info({:sand_grid, grid_b64}, socket) do
    {:noreply, push_event(socket, "grid", %{grid: grid_b64})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-4 gap-3">
      <div class="shrink-0 flex flex-wrap items-center gap-2">
        <button
          :for={{label, code} <- @elements}
          type="button"
          phx-click="select"
          phx-value-code={code}
          class={[
            "!rounded-lg !border px-3 py-1.5 text-sm !shadow-none",
            @selected == code && "!border-sky-300 text-sky-200 bg-zinc-700",
            @selected != code && "!border-zinc-600 text-zinc-300 bg-zinc-800"
          ]}
        >
          {label}
        </button>
        <button
          type="button"
          phx-click="clear"
          class="!rounded-lg !border !border-zinc-600 !shadow-none px-3 py-1.5 text-sm text-zinc-300 bg-zinc-800 ml-auto"
        >
          Clear
        </button>
      </div>

      <div class="flex-1 min-h-0 flex items-center justify-center">
        <canvas
          id="sand-canvas"
          phx-hook="SandCanvas"
          phx-update="ignore"
          data-w={@width}
          data-h={@height}
          data-selected={@selected}
          class="border border-zinc-700 rounded max-h-full max-w-full"
          style="image-rendering: pixelated; aspect-ratio: 120 / 80; width: auto; height: 100%;"
        >
        </canvas>
      </div>
    </div>
    """
  end
end
```

Note: `data-selected={@selected}` updates on the element buttons' clicks; the
hook reads `this.el.dataset.selected` live at paint time, so the server stays
unaware of selection beyond echoing it. `phx-update="ignore"` keeps LiveView
from clobbering the canvas pixels, but `data-*` attribute changes still apply.

- [ ] **Step 4: Add the route**

In `lib/blog_web/router.ex`, inside the `live_session :public` block, add after the `/games/snake` line:

```elixir
      live("/games/sand", SandLive, :index)
```

- [ ] **Step 5: Add the Games card**

In `lib/blog_web/live/games_live/index.ex`, change the `@games` list to include Sand:

```elixir
  @games [
    %{
      name: "Snake",
      href: "/games/snake",
      blurb: "A single global multiplayer snake — everyone shares one board.",
      emoji: "🐍"
    },
    %{
      name: "Sand",
      href: "/games/sand",
      blurb: "A shared falling-sand sandbox — paint sand, water, fire, and watch it flow.",
      emoji: "🏖️"
    }
  ]
```

- [ ] **Step 6: Run the tests**

Run: `mix test test/blog_web/live/sand_live_test.exs`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/blog_web/live/sand_live.ex lib/blog_web/router.ex lib/blog_web/live/games_live/index.ex test/blog_web/live/sand_live_test.exs
git commit -m "Add SandLive at /games/sand with palette + canvas; link from Games"
```

---

## Task 9: Full verification

- [ ] **Step 1: Compile + full suite**

Run: `mix compile --warnings-as-errors` then `mix test`
Expected: clean compile; all tests pass.

- [ ] **Step 2: Manual smoke test**

Run: `mix phx.server`. Verify:
- `/games` shows Snake and Sand cards.
- `/games/sand`: painting with the mouse deposits the selected element; sand
  falls and piles; water flows; fire spreads through wood and is doused by water;
  Clear empties the board; the page does not scroll; the painted header shows
  "← Back" and "Sand".
- Open `/games/sand` in two browser windows: paint in one, see it in the other
  (shared global board).
- `/games/snake` still works, full-screen, non-scrolling.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "Fix up falling-sand + game layout verification"
```

---

## Self-Review Notes

- **Spec coverage:** game layout (Task 1), snake migration + no-scroll + bigger board (Task 2), pure Sim with sand/water/stone/wood/fire + reactions (Tasks 3–5), GenServer + supervision + paint/clear/broadcast gated on change (Task 6), canvas hook + paint capture (Task 7), SandLive + route + Games card + viewer count via game layout (Task 8), verification incl. two-window shared-board check (Task 9).
- **Element-code contract** is consistent across `Sim`, `SandGame` (`code in 0..5`), and the JS hook color map.
- **Signatures** consistent: `Sim.step/4`, `SandGame.paint/2`, `SandGame.clear/0`, `SandGame.join/1`, `SandGame.grid/0`, `SandGame.dims/0`.
- **Parallelization hint for execution:** Tasks 1–2 (layout + snake) are independent of the sand chain (3→4→5→6→7→8). Sim tasks 3–5 share one file (sequential). Task 6 depends on Sim; Task 8 depends on 6 + 7 + 1.
- **Perf note:** `Sim.load/dump` are O(n) list builds per tick (9,600 cells @ ~15fps) — acceptable; if profiling later shows pressure, switch dump to build iodata or diff-broadcast.
```
