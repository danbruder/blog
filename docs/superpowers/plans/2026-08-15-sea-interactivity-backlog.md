# Sea Interactivity Backlog

A running list of ideas for making the `/sea` 3D easter egg more fun for
people who join, to work through one at a time. Not a single implementation
plan — each item gets scoped and built on its own, in priority order, and
checked off here as it ships.

**Baseline (already shipped, for context — see
`docs/superpowers/specs/2026-07-25-3d-sailing-easter-egg-design.md`):**
islands derived from every page, live multiplayer sailing over `SeaChannel`
at ~12 Hz, reader boats anchored at their page's island with a country-flag
sail, docking navigates to the post, ambient sharks that patrol/breach/bite,
chase cam, keyboard + touch controls, sidebar minimap.

## Status

| # | Item | Status |
|---|---|---|
| 1 | Arrival/departure toast | Done |
| 2 | Ambient + event sound (muted by default) | Done |
| 3 | Wave/emote key | Done |
| 4 | Message in a bottle | Done |
| 5 | Trending islands from analytics | Done |
| 6 | Regatta / buoy objective | Done |
| 7 | Day/night cycle (Eastern time) | Not started |
| 8 | Wake trails | Not started |
| 9 | More ambient creatures/hazards | Not started |
| 10 | Boat customization | Not started |

---

## 1. Arrival/departure moments

A toast/banner when a sailor joins or leaves the sea (e.g. "🇯🇵 a sailor has
joined the sea"), driven off `SeaChannel`'s presence diff / `"gone"` event.
Makes the world feel alive instead of just populated.

## 2. Ambient + event sound

There's currently no audio in the scene. Add ambient waves/gulls plus short
one-shots for collision splash, shark bite, and docking. **Must default to
muted** — sound only starts after an explicit user opt-in (a mute/unmute
control in the overlay), never autoplaying audio on entry. Persist the
preference (localStorage) so it doesn't reset every visit.

## 3. Wave/emote key

A single low-effort social gesture — press a key to honk a horn / wave a
flag / send up a firework — broadcast over `SeaChannel` like `pos` already
is. Deliberately not chat: no text, no replies, just an acknowledgement.

## 4. Message in a bottle

Let a sailor drop a short (~80 char), ephemeral note that floats at a spot;
other sailors read it by sailing close and pressing a key. No persistence
beyond the channel's lifetime, no moderation queue — stays in the spirit of
the "no chat" non-goal.

## 5. Trending islands from analytics

Surface `Blog.Analytics` view data in the world — a trending post's island
stands out (taller, glowing, more palms) so exploring the sea surfaces
what's popular right now.

## 6. Regatta / buoy objective

A chain of buoys to pass in order, with a session timer and maybe an
ephemeral "fastest today" leaderboard shared over the roster. Gives sailing
a goal beyond docking.

## 7. Day/night cycle

Tie the sky/lighting to real time of day instead of always looking the
same. **Follow US Eastern time (America/New_York)** regardless of visitor
timezone, so everyone sailing together sees the same sky at the same
moment.

## 8. Wake trails

A fading plane strip behind moving boats so multiplayer sailing looks like
sailing and you can see where people have been.

## 9. More ambient creatures/hazards

Beyond sharks: flying fish, an occasional surfacing whale, floating
driftwood — variety without added gameplay complexity.

## 10. Boat customization

Let a visitor pick a hull color or flag emoji (localStorage-persisted)
instead of always deriving hull color from a hash of the session id.
