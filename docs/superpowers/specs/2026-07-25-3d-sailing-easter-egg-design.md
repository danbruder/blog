# 3D Sailing Easter Egg — Design

**Date:** 2026-07-25
**Status:** Approved (brainstorming)

## Summary

A hidden third "theme" turns the blog into a shared 3D toon ocean. The existing
Light → Dark theme toggle gains a third stop, **Sea**. Cycling to Sea replaces
the current page with a full-screen three.js archipelago where **every page on
the blog is an island**. The visitor sails a little flag-boat between islands;
nearing an island floats up its post title, and "docking" exits Sea mode and
navigates to that post to read normally. Toggling back to Light or Dark drops out
of the world at any time.

Every currently-connected visitor is represented in the same sea in real time:
people just reading a page appear as boats anchored at that page's island;
people actively in Sea mode appear as boats sailing around live. The blog itself
is completely untouched — this feature is purely additive.

## Goals

- A delightful, discoverable easter egg that showcases the blog's real-time
  presence and personality.
- Reuse the existing `site_presence` Presence system as the roster of who is here.
- Make the sea feel populated even when only one person has entered Sea mode.
- Zero impact on normal page loads and normal reading (lazy-loaded 3D, no bundle
  bloat, no changes to existing reading UX).

## Non-Goals (v1)

- No accounts or persistent identity (flag + ephemeral session only).
- No chat or text between visitors.
- No editable boat names.
- No collision/physics beyond simple steering.
- No persistence of boat positions (fully ephemeral).
- Boats are cosmetically identical apart from country flag + a highlight on the
  visitor's own boat.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Role of the 3D world | Ambient easter egg layered on the real blog |
| Motif | Sailing / island-hopping |
| Multiplayer fidelity | Live sailing sync for people in Sea mode |
| Readers (not in Sea mode) | Appear anchored at the island of the page they're on |
| Entry point | Third theme state: Light → Dark → Sea |
| Docking behavior | Title floats up on approach; dock to exit Sea mode and open the post |
| Boat identity | Country flag on the sail (from existing GeoIP data) |
| Art direction | Bold toon / cel — flat fills, thick ink outlines, system-v2 palette |
| Island coverage | Every significant route is an island (confirmed default A) |
| Position sync | Real ~12 Hz channel sync built in v1 (confirmed default B) |

## The World

- **Look:** bold cel-shaded. Flat lime islands, signal-blue faceted sea, ink
  outlines on boats/islands (inverted-hull outline), paper-colored sky. All
  colors resolve from the existing system-v2 tokens
  (`--color-paper`, `--color-ink`, `--color-lime`, `--color-signal`) so the
  world matches the blog's identity.
- **Islands = pages.** Every significant public route is an island: each blog
  post, each note, and the section index pages (writing, notes, projects, games,
  podcasts). **Home (`/`) is the harbor**, the spawn point.
- **Layout:** a loose archipelago clustered by section, with the newest posts
  nearest the harbor. The island set and positions are **derived from
  `Blog.Content`** at page load and passed to the client, so publishing a new
  post automatically adds a new island — no hand-maintained map.
- **Island label:** each island shows its page title on a floating cel banner
  when the boat is near.

## Presence & Sync Architecture

Two data layers, deliberately separated by update frequency.

### Roster (low-frequency) — reuses existing Presence

- Source: the existing `site_presence` `Phoenix.Presence` topic that
  `PresenceTracker` already populates for every public LiveView.
- **Change:** extend each visitor's presence meta to also carry their
  **current path** (which island) alongside the existing `country`. Update the
  path in the meta on navigation (the `CurrentPath` / `handle_params` hook is the
  natural place).
- Drives every **reader's** boat: anchored and gently bobbing at the island of
  the page they are on, country flag on the sail. When a reader navigates, their
  boat glides to the new island.
- The mounted LiveView pushes roster snapshots to the JS scene via `push_event`
  on presence diffs (join / leave / navigate only — low frequency).

### Positions (high-frequency) — new lightweight channel

- New **`SeaChannel`** (topic e.g. `sea:ocean`).
- Only visitors **actively in Sea mode** join it. They broadcast their
  `{x, z, heading}` at ~12 Hz; the server fans the update out to the other
  channel members.
- Sailors render each other's boats moving live with **client-side
  interpolation** between updates.
- A sailor is drawn at their **live position** instead of their anchored island.
  (The roster still lists them; the client prefers a live position when one is
  present for that session id.)

Net effect: readers = anchored flag-boats (nearly free, from Presence);
sailors = live moving flag-boats (from the channel). Sessions are correlated
between the two layers by the LiveView/session id already used as the Presence
key.

## Controls

- **Desktop:** arrow keys / WASD to steer and throttle. Space to dock when within
  an island's dock radius.
- **Touch:** on-screen drag joystick + a Dock button, following the mobile
  control pattern already used by the snake game.
- **Camera:** chase cam following behind the boat.
- **Docking:** enter an island's dock radius, then press Space / tap Dock →
  exit Sea mode and `navigate` to that page.

## Technical Shape (Phoenix + esbuild)

- **three.js** added to `assets/package.json`, **dynamically `import()`-ed** only
  when Sea mode activates, so the main JS bundle and normal page loads are
  unaffected. esbuild bundles it into a lazily-loaded chunk.
- **Sea theme state:** extend the existing `ThemeToggle` hook so the theme cycles
  Light → Dark → Sea, persisted to `localStorage` like the current theme. A
  `sea` theme value activates the scene.
- **`Sea` JS hook / module:** owns the three.js scene, camera, boat, islands, and
  render loop. Receives roster snapshots via `push_event` from its host
  LiveView; connects to `SeaChannel` for live positions; broadcasts the local
  boat's position while sailing.
- **`SeaChannel` (new):** joins/leaves + position fan-out. Ephemeral, no storage.
- **`PresenceTracker` (small change):** include `path` in the tracked meta and
  update it on navigation so anchored boats know their island.
- **Island data:** a small server-side function derives the island list
  (route → title → section → position seed) from `Blog.Content` and passes it to
  the client on mount.

## Testing

- Presence meta carries and updates `path` on navigation (Elixir test around
  `PresenceTracker` / the tracking hook).
- `SeaChannel` join, position broadcast fan-out to other members, and leave
  (Phoenix channel test).
- Island-derivation function returns one island per significant route and stays
  in sync with `Blog.Content` (Elixir unit test).
- Theme cycling Light → Dark → Sea → Light (JS/hook-level; at minimum a manual
  check, ideally a small unit test of the cycle function).
- Manual end-to-end: two browser sessions, one reading + one sailing, confirm the
  reader appears anchored at its island and the sailor moves live; docking
  navigates and exits Sea mode.

## Risks / Open Considerations

- **Bundle size:** three.js is large; strict dynamic import + tree-shaking keeps
  it off the critical path. Verify normal page weight is unchanged.
- **Position bandwidth:** 12 Hz × sailors is fine at blog scale; if a crowd ever
  appears, throttle/round positions and cap broadcast rate server-side.
- **Session correlation:** the client must line up a channel position with the
  right roster entry via a shared session id; keep that id consistent across the
  Presence key and the channel join.
- **Mobile performance:** cel shading + outlines are cheap; keep island/boat
  counts modest and test on a phone.
