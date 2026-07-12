# Home Landing Page — Design

**Date:** 2026-07-12
**Status:** Draft — decisions assumed while user was away (Writing→`/writing`, full-width bands w/ light live content). Confirm before/at execution.

## Summary

Turn `/` into a **Home landing page** with a short intro hero followed by
**full-width scrollable bands**, one per subsection (Writing, Notes, Games,
Podcasts, Projects), each with a blurb + "explore" link so visitors can scroll
and pick where to go. Move the existing posts list off `/` to **`/writing`**.
Add a **Home** link to the sidebar.

## Goals

- `/` renders a Home landing (hero + one band per subsection).
- Writing (the published-posts list) moves to `/writing`, unchanged in content.
- Sidebar gains **Home** (top), and **Writing** now points at `/writing`.
- Active-nav highlighting: Home active only on `/`; Writing active on `/writing`
  and `/blog/:slug` posts.
- Uses the normal sidebar (`:app`) layout; bands live in the grey body and scroll.

## Non-Goals

- No redirect from `/` (it still exists, just renders the landing now).
- No new content types; Games/Podcasts/Projects bands are static blurbs.
- No carousel/JS — plain vertical scroll.

## Routing & modules

- **`BlogWeb.HomeLive`** (existing, at `/`) — **repurposed** into the landing. It
  loads the latest post + latest note (via `Blog.Content`) for the Writing/Notes
  bands and renders the hero + bands.
- **`BlogWeb.WritingLive`** (new, at `/writing`) — the current posts-list render
  moved out of `HomeLive` verbatim (hero "Writing" + latest posts + notes hint).
- Router: keep `live("/", HomeLive, :index)`; add
  `live("/writing", WritingLive, :index)`.

## Home landing content

- **Hero** (`<.page_hero>`): title "Hi, I'm Dan", subtitle one-liner (e.g.
  "Engineering director making reality capture easy — here's what's around.").
- **Bands** (one `<section>` each, generous vertical padding, alternating subtle
  background for rhythm), in order:
  - **Writing** — blurb + latest post title/date (if any) → link `/writing`.
  - **Notes** — blurb + latest note title/date (if any) → link `/notes`.
  - **Games** — blurb ("Multiplayer toys — Snake and a shared falling-sand
    sandbox.") → link `/games`.
  - **Podcasts** — blurb → link `/podcasts`.
  - **Projects** — blurb ("Coming soon.") → link `/projects`.
- Each band: section title (heading accent), 1–2 sentence blurb, optional latest
  item line, and an explore link styled like `.link`.

## Sidebar changes (`app.html.heex`)

- Prepend a **Home** item: `{"Home", ~p"/", "🏠"}`; change Writing to
  `{"Writing", ~p"/writing", "✍️"}`.
- Update `active?`:
  - `/` (Home): active only when `current == "/"`.
  - `/writing` (Writing): active when `current == "/writing"` or
    `String.starts_with?(current, "/blog")` (posts).
  - Others: `current == href or String.starts_with?(current, href <> "/")`
    (unchanged).
- Since Home now owns `/`, remove the special `"/" → /blog` matching that
  currently makes Writing light up on posts; that logic moves to the Writing item.

## Files

**New:**
- `lib/blog_web/live/writing_live.ex`
- `test/blog_web/live/writing_live_test.exs`

**Modified:**
- `lib/blog_web/live/home_live.ex` — becomes the landing.
- `lib/blog_web/router.ex` — add `/writing`.
- `lib/blog_web/components/layouts/app.html.heex` — Home nav item + active logic.
- `test/blog_web/live/home_live_test.exs` — assert landing content, not the list.

## Testing

- **HomeLive:** `/` renders the hero and a band per subsection with links to
  `/writing`, `/notes`, `/games`, `/podcasts`, `/projects`; shows the latest post
  title when one exists.
- **WritingLive:** `/writing` lists published posts (not notes), like the old `/`.
- **Sidebar:** on `/`, Home is the active link; on `/writing`, Writing is active;
  on a `/blog/:slug` post, Writing is active.

## Risks / Notes

- Anyone linking to `/` expecting the posts list now sees the landing; the posts
  are one click away under Writing. Acceptable; no redirect.
- Decisions (Writing path, band style) were assumed while the user was away —
  confirm before merge.
