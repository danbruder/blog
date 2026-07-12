# Falling-Sand Game + Viewport-Locked Game Layout — Design

**Date:** 2026-07-12
**Status:** Draft (pending user review)

## Summary

Add a shared, global **falling-sand sandbox** at `/games/sand` — a communal
cellular-automaton toy (sand, water, stone, wood, fire) that everyone viewing
paints into together, following the same authoritative-GenServer + PubSub
pattern as `Blog.SnakeGame`.

Introduce a dedicated **game layout** used by the individual game views
(`/games/snake` and `/games/sand`, but NOT the `/games` landing): no sidebar, a
compact `.painted` header (back button + game name + viewer count), and a
**viewport-locked, non-scrolling** shell so games use the full screen and arrow
keys can't scroll the page. Migrate the existing Snake view onto this layout and
let its board grow to fill the space.

## Goals

- A working shared falling-sand sandbox with sand/water/stone/wood/fire + eraser,
  including reactions (fire burns wood & spreads; water douses fire; sand sinks
  through water).
- One global canvas shared by all viewers, driven by an authoritative GenServer;
  a Clear button anyone can press; memory-only state (resets on restart).
- A reusable game layout: full-width, viewport-locked (`h-[100dvh]`,
  `overflow-hidden`), compact painted header with a back button and viewer count.
- Snake migrated to the game layout with a much larger board; no page scroll.
- Physics implemented as pure, unit-tested functions.

## Non-Goals

- No per-visitor identity/tint or live cursors (shared canvas + viewer count only).
- No persistence across restarts (no DB/disk).
- No extra elements beyond the six listed (oil/plant/acid are out).
- No per-tick cell-diff broadcast optimization initially (full-grid broadcast,
  gated on change; diffing noted as a future optimization).

## Architecture

Mirrors `Blog.SnakeGame`, with one structural improvement: physics live in a
pure module separate from the process.

- **`Blog.SandGame`** (GenServer, registered by module name, added to the
  supervision tree in `lib/blog/application.ex` after `Blog.SnakeGame`). Owns the
  authoritative grid, monitors viewer pids (for the viewer count + cleanup on
  disconnect), applies paint/clear, ticks on `:timer.send_interval`, and
  broadcasts over `Blog.PubSub` on topic `"sand"`.
- **`Blog.SandGame.Sim`** — pure functions, no process state. Public entry:
  `step(grid, opts) :: grid`. All movement/reaction rules live here and are
  unit-tested directly.
- **`BlogWeb.SandLive`** — LiveView at `/games/sand`. Renders the element palette
  + Clear button + `<canvas>`; subscribes to `"sand"`; relays grid updates to the
  JS hook via `push_event`; sends `paint`/`clear` events to the GenServer. Uses
  `layout: {BlogWeb.Layouts, :game}` and sets `@game_name "Sand"`.
- **`SandCanvas` JS hook** (`assets/js/app.js`) — draws the grid to a `<canvas>`
  (element → color map keyed by byte code) and captures mouse/touch drag as paint
  strokes. `preventDefault`s arrow/space keys while focused.

### Grid representation

- A **binary, one byte per cell**, row-major, index `= y * width + x`.
- Element codes: `0` empty, `1` sand, `2` water, `3` stone, `4` wood, `5` fire.
- Dimensions: **`@width 120`, `@height 80`** (9,600 bytes).
- **Tick: `@tick_ms 66`** (~15 fps). A fresh grid binary is produced each tick.

### Data flow

1. On mount, `SandLive` calls `SandGame.join(self())` → gets `{viewer_count, grid}`
   and pushes the full grid to the hook; subscribes to `"sand"`.
2. Drag on the canvas → hook computes affected cell indices within a brush radius
   → throttled to one `paint` event per animation frame →
   `%{"cells" => [i, ...], "element" => code}` → `SandLive` casts
   `SandGame.paint/2` → cells stamped into the authoritative grid immediately.
3. Each tick: `SandGame` runs `Sim.step/2`; if the grid changed, broadcasts
   `{:sand_grid, base64_grid, viewer_count}` on `"sand"`.
4. `SandLive` receives the broadcast and `push_event`s the grid to the hook,
   which repaints the canvas. Viewer count is shown in the game-layout header.
5. Clear button → `SandGame.clear/0` → grid reset to all-empty → broadcast.
6. Viewer join/leave changes the monitored-pid set → broadcast so the count
   updates live.

## Simulation rules (`Sim.step/2`)

Scan **bottom row upward** (so a particle that falls isn't re-processed as it
lands), and **randomize horizontal preference** per tick/cell to avoid a
left/right bias. Track a `moved` MapSet of destination indices so a cell isn't
written twice in one tick.

- **Sand (1):** move down if the cell below is empty or water (sand sinks through
  water — they swap); else move to a random open down-diagonal; else stay.
- **Water (2):** move down if empty; else spread to an open down-diagonal; else
  move sideways to a random adjacent open cell (flows flat).
- **Stone (3):** never moves.
- **Wood (4):** never moves on its own; can be converted to fire by an adjacent
  fire cell.
- **Fire (5):** for each orthogonally-adjacent **wood** cell, ignite it (convert
  to fire) with probability `p_ignite`. If any orthogonal neighbor is **water**,
  the fire is extinguished (→ empty). Otherwise the fire self-extinguishes with
  probability `p_burnout` (→ empty), giving a flicker. Fire fed by wood tends to
  persist and spread; isolated fire dies out.

Randomness: the GenServer generates a per-tick seed and passes it into
`step/2` (via `opts`) so `Sim` stays free of global RNG and tests can pass a
fixed seed for determinism.

## Game layout (`lib/blog_web/components/layouts/game.html.heex`, new)

Used only by game *views* via each LiveView's `mount` returning
`{:ok, socket, layout: {BlogWeb.Layouts, :game}}`. The `/games` landing keeps the
default sidebar (`:app`) layout. No router changes.

Structure:

```
<div class="h-[100dvh] flex flex-col overflow-hidden">
  <header class="painted shrink-0 relative overflow-hidden border-b border-zinc-800">
    <div class="relative z-10 flex items-center justify-between px-4 py-3">
      <.link navigate={~p"/games"} class="... no-underline">← Back</.link>
      <span class="font-fancy text-lg">{assigns[:game_name]}</span>
      <span class="text-sm text-zinc-400">
        {viewer_count} watching   <!-- if assigned -->
      </span>
    </div>
  </header>
  <main class="flex-1 min-h-0 overflow-hidden">
    {@inner_content}
  </main>
</div>
<.flash_group flash={@flash} />
```

- `h-[100dvh] overflow-hidden` makes the page exactly the viewport with nothing
  to scroll → arrow/space keys cannot scroll.
- Header carries the `.painted` shape background (`relative z-10` inner wrapper
  keeps text above the shapes), matching the hero treatment.
- `@game_name` is set by each game LiveView; `viewer_count` shown when assigned.
- `flash_group` is kept so flashes still work.

The layout must be declared in `BlogWeb.Layouts` (it uses
`embed_templates "layouts/*"` — the new file is picked up automatically).

## Snake migration

`lib/blog_web/live/snake_live.ex`:
- `mount` returns `{:ok, socket, layout: {BlogWeb.Layouts, :game}}` and assigns
  `game_name: "Snake"` (also pass `viewer_count` if available for the header).
- Remove the `<.page_hero>` and the outer `max-w-7xl`/`max-w-5xl` wrappers.
- The game area fills the layout's `<main>`: a `flex` row (column on mobile) with
  the board taking the space and the players panel as a compact side column.
- Board SVG grows to fill: `class="snake h-full w-auto max-w-full max-h-full"`
  with `preserveAspectRatio="xMidYMid meet"` (unchanged), centered in a
  `flex-1 min-h-0 flex items-center justify-center` container.
- Players panel: fixed-ish width, `overflow-y-auto` so a long list scrolls
  *inside the panel* (the page never scrolls).
- The "arrow keys / WASD" text becomes a small caption near the board.
- The mobile on-screen dpad is retained (mobile has no arrow-scroll issue).

## SandLive view

- Full-height flex within the game layout's `<main>`: a palette bar (`shrink-0`)
  and the canvas filling the rest.
- Palette: six element buttons (Sand/Water/Stone/Wood/Fire/Erase) with the
  selected one visually active; a **Clear** button. Selecting an element sets a
  `@selected` assign passed to the hook (or tracked client-side and sent with each
  paint event — see below).
- Canvas: internal resolution `120×80`, CSS-scaled to fit the game area,
  `style="image-rendering: pixelated"`, preserving aspect ratio
  (`max-h-full max-w-full`).
- The selected element and brush radius are tracked **client-side in the hook**
  (updated via a `phx-click` that also `push_event`s, or via `data-` attributes
  the hook reads); each `paint` event carries the element code so the server
  stays stateless about selection. Brush radius default 2 cells (no size selector
  in v1 — YAGNI).

## Files

**New:**
- `lib/blog/sand_game.ex` — GenServer.
- `lib/blog/sand_game/sim.ex` — pure physics.
- `lib/blog_web/live/sand_live.ex` — LiveView.
- `lib/blog_web/components/layouts/game.html.heex` — game layout.
- `test/blog/sand_game/sim_test.exs`
- `test/blog/sand_game_test.exs`
- `test/blog_web/live/sand_live_test.exs`

**Modified:**
- `lib/blog/application.ex` — add `Blog.SandGame` to the supervision tree.
- `lib/blog_web/router.ex` — add `live("/games/sand", SandLive, :index)`.
- `lib/blog_web/live/games_live/index.ex` — add a Sand card to the grid.
- `lib/blog_web/live/snake_live.ex` — migrate to game layout + bigger board.
- `assets/js/app.js` — register the `SandCanvas` hook; `preventDefault` arrow/space
  keys for game views.

## Testing

- **`Sim` unit tests** (pure, deterministic with a fixed seed):
  - sand falls into empty space below; piles when blocked; slides diagonally.
  - sand sinks through water (they swap).
  - water falls; spreads sideways to fill a flat surface.
  - stone and wood do not move on their own.
  - fire ignites adjacent wood; fire adjacent to water is extinguished; isolated
    fire burns out.
  - moved-guard: a single particle moves at most one cell per tick.
- **`SandGame` tests:** `paint/2` stamps the given cells with the element;
  `clear/0` empties the grid; `join/1` returns the current grid + count and
  monitors the pid; a monitored pid going down decrements the count.
- **`SandLive` test:** `/games/sand` renders (palette buttons, Clear, canvas),
  uses the game layout (no sidebar nav present), and `/games` shows a Sand card
  linking to `/games/sand`.

## Risks / Notes

- **Broadcast bandwidth:** full 9,600-byte grid (~13 KB base64) at 15 fps per
  active viewer. Fine for a personal site; gated on change so an idle/settled
  board is silent. Per-tick diffing is the escape hatch if a crowd appears.
- **BEAM CPU:** ~9,600 cell-ops per tick × 15 fps is trivial; the sim runs only
  while at least one viewer is connected AND the grid is non-empty/active.
- **`100dvh`:** chosen over `100vh` to handle mobile browser chrome; game views
  are primarily a desktop experience but should not break on mobile.
