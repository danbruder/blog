# Sidebar Layout + Painted Heros — Design

**Date:** 2026-07-12
**Status:** Approved (pending spec review)

## Summary

Restructure the blog from a top-header, single-column layout into a **persistent
left sidebar + content column** layout. Move the identity block (face, name, bio,
"about me") into the sidebar and give it the primary navigation: Writing, Notes,
Games, Podcasts, Projects.

Change the dynamic CSS Paint Worklet background (`.painted`) so its random shapes
render **only in a hero band** at the top of each page (and above each post/note
title). The rest of the page — sidebar and body — becomes flat grey (`zinc-900`).

Add two new pages (Podcasts, Projects) and a Games landing that lists games and
links through to Snake.

## Goals

- Persistent left sidebar on every public page, carrying identity + nav.
- Painted shapes confined to hero bands; flat grey everywhere else.
- New nav: Writing (`/`), Notes (`/notes`), Games (`/games`), Podcasts
  (`/podcasts`), Projects (`/projects`).
- Games as a landing that lists games; Snake nested at `/games/snake`.
- Podcasts page holds the "Software Unscripted" appearance (extracted from About).
- Projects page = "coming soon".
- Responsive: sidebar collapses to a top bar with a toggle on narrow screens.

## Non-Goals

- No change to content storage, admin, feeds/SEO, or the Snake multiplayer engine.
- No new games beyond Snake (Games grid just leaves room for them).
- No visual redesign of typography/colors beyond the layout + hero change.

## Layout Shell (`lib/blog_web/components/layouts/app.html.heex`)

Replace the current top `<header>` with a flex row: sidebar + main content column.
Keep the existing viewer-count widget (fixed bottom-right) and flash group.

**Sidebar** (desktop `md+`): fixed-width (~`w-60`), flat `zinc-900`, right border
(`border-zinc-800`), vertical stack:
- Face photo (`/images/my-face-new.jpg`, rounded).
- "Dan Bruder" (Work Sans / `font-fancy`).
- One-line bio: "Engineering director making reality capture easy." (links
  "reality capture" → dronedeploy.com).
- Nav links (Work Sans): Writing, Notes, Games, Podcasts, Projects. Active link
  highlighted using the existing `@current_path` (from the `CurrentPath`
  on_mount). Active state = subtle bg + heading-accent text.
- Footer row (small, `zinc-500`): "👋 about me" (→ `/blog/about`), RSS (→
  `/rss.xml`), GitHub, and "© <year> Dan Bruder".

**Content column**: `flex-1`, `min-w-0`, flat `zinc-900`. Each LiveView renders
its own `<.page_hero>` + body inside it. Keep a comfortable reading measure for
body content (e.g. inner `max-w-3xl` wrapper) but let the hero span the column.

**Active-link helper:** add a small private function or inline logic in the layout
that compares `@current_path` against each nav href and applies active classes.
`@current_path` is already assigned via `BlogWeb.CurrentPath`.

### Mobile (`< md`)

Sidebar collapses to a compact **top bar**: face + "Dan Bruder" on the left, a
hamburger button on the right. Tapping the hamburger toggles the nav list
(shown stacked below the bar). Content is full-width below.

Implementation: a tiny JS hook (`MobileNav`) registered in `assets/js/app.js`,
matching the existing hook pattern (e.g. `Highlight`, `DblClickEdit`). The hook
toggles a `hidden` class on the nav container. No new dependencies. Desktop
sidebar and mobile bar are the same markup shown/hidden via Tailwind responsive
utilities; the hook only drives the mobile collapse.

## Painted Hero Component

**CSS (`assets/css/app.css`):**
- Remove `.painted` from `<body>` in `root.html.heex` — body stays
  `bg-zinc-900 text-zinc-50`.
- Keep the `.painted { background-image: paint(myPaintedBackground); }` rule; it
  will now be applied to the hero element instead of the body.
- The paint worklet (`assets/js/paintWorklet.js`) is unchanged.

**Component (`lib/blog_web/components/core_components.ex`):** add
`<.page_hero>`:

```
attr :title, :string, required: true
attr :subtitle, :string, default: nil
attr :eyebrow, :string, default: nil      # small label above title (optional)
slot :inner_block                          # optional extra content (e.g. post date)

# Renders:
# <section class="painted relative overflow-hidden border-b border-zinc-800 ...">
#   <div class="relative z-10 ...">  (padding, max width matching content)
#     eyebrow?, <h1> title, subtitle?, inner_block
#   </div>
# </section>
```

The `.painted` class supplies the shape background; a `relative z-10` inner
wrapper keeps text above the shapes. Hero base background is a slightly deeper
tone than the body so shapes read (e.g. `bg-zinc-950`), matching the mockup.

## Pages & Routes

Router changes (`lib/blog_web/router.ex`, `:public` live_session unless noted):

| Nav | Route | Module | Hero title | Body |
|-----|-------|--------|-----------|------|
| Writing | `/` | `HomeLive` (existing) | "Writing" | Latest posts list. The "Hi, I'm Dan" hero block is removed (its content now lives in the sidebar bio). |
| Notes | `/notes` | `NoteLive.Index` (existing) | "Notes" | Notes list (unchanged content). |
| Games | `/games` | `GamesLive.Index` (**new**) | "Games" | Responsive grid of game cards. One card: **Snake** (title + short blurb) → `/games/snake`. Structured to add more cards later. |
| — | `/games/snake` | `SnakeLive` (existing, route moved) | "Snake" | Multiplayer game, unchanged logic; gains `<.page_hero>`. |
| Podcasts | `/podcasts` | `PodcastLive.Index` (**new**) | "Podcasts" | "Appearances" — a styled card for the **Software Unscripted** episode (show name, episode blurb, "Listen" link to the Spotify URL). Room for more entries. |
| Projects | `/projects` | `ProjectLive.Index` (**new**) | "Projects" | "Coming soon" message. |
| — | `/blog/about` | `PostLive.Show` (existing) | About post title | About page kept; the Software Unscripted paragraph removed from its body. |
| — | `/snake` | redirect | — | **301 redirect** to `/games/snake` (preserve old links). |

**Snake route move:** change `live("/snake", SnakeLive, :index)` to
`live("/games/snake", SnakeLive, :index)`. Add a redirect for the old path. The
existing `RedirectReclassifiedNote` plug is a precedent for path redirects; add a
simple `get "/snake"` redirect (controller or `Phoenix.Router` `redirect/2`)
returning 301 to `/games/snake`.

**Podcasts data:** the Software Unscripted episode details are hardcoded in
`PodcastLive.Index` (title, blurb, Spotify URL
`https://open.spotify.com/episode/6cnAHvdCXedoHxG4w9pWOV`). Presentation: a styled
"appearance" card (reuse the `.browser`/card border styling), not a Spotify
iframe embed.

**About edit:** remove the sentence "I shared our experience using Elm + Rust at
StructionSite on the Software Unscripted podcast last year." from the About post
body in the database (`posts` where `slug='about'`). This is a data edit, not a
content-file edit (About lives in the DB). Document the exact removal so it can be
applied to prod (`blog_dev.db` for dev; note that prod DB needs the same edit).

## Files Touched

**New:**
- `lib/blog_web/live/games_live/index.ex` — Games landing (grid of game cards).
- `lib/blog_web/live/podcast_live/index.ex` — Podcasts appearances.
- `lib/blog_web/live/project_live/index.ex` — Projects "coming soon".

**Changed:**
- `lib/blog_web/components/layouts/app.html.heex` — sidebar shell + mobile bar.
- `lib/blog_web/components/layouts/root.html.heex` — drop `painted` from `<body>`.
- `lib/blog_web/components/core_components.ex` — add `<.page_hero>`.
- `lib/blog_web/router.ex` — new routes, moved Snake route, `/snake` redirect.
- `lib/blog_web/live/home_live.ex` — use `page_hero`; drop "Hi I'm Dan" block.
- `lib/blog_web/live/note_live/index.ex` — use `page_hero`.
- `lib/blog_web/live/post_live/show.ex` — use `page_hero` (title + date in hero).
- `lib/blog_web/live/snake_live.ex` — use `page_hero` ("Snake").
- `assets/css/app.css` — `.painted` now scopes to hero; body stays grey.
- `assets/js/app.js` — register `MobileNav` hook.
- About post body in DB — remove the Software Unscripted sentence.

## Testing

- **Existing tests:** run the full suite; fix any that assert on the old
  `/snake` path or the old home hero copy.
- **New tests (LiveView):**
  - `/games` renders and shows a Snake card linking to `/games/snake`.
  - `/games/snake` renders the game (existing Snake behavior tests still pass).
  - `/podcasts` renders and shows a "Software Unscripted" link to the Spotify URL.
  - `/projects` renders "coming soon".
  - `/snake` returns a 301 redirect to `/games/snake`.
  - Sidebar nav appears on a representative page and marks the active link.
- **Manual/visual:** verify shapes appear only in the hero, body is flat grey,
  sidebar persists across navigation, and the mobile top-bar toggle works.

## Open Questions / Risks

- **Prod DB About edit:** the About body edit must be applied to the production
  database as well as dev; it is not captured in a content file. Flag during
  deploy.
- **Painted hero performance:** the worklet redraws random shapes per paint;
  scoping it to a small hero (vs. full body) should reduce work, not increase it.
