# SEO + design polish (Tier 1 & Tier 3)

Implements the "quick fixes / sharing / design" items from the 2026-07 review
todos in `README.md`. Scope is deliberately bounded to Tier 1 (title +
discoverability) and Tier 3 (design consolidation + accessibility). The
information-architecture items (Selected writing, /notes, Projects, homepage
hierarchy redesign) are explicitly **out of scope** — they need their own pass.

Decisions below were made with the user away, using the recommended options
from the brainstorming questions. Flagged for review.

## Tier 1 — title & discoverability

### 1. Title consistency
- `<title>` default and page-title assigns currently say "Software Engineering
  Manager"; hero says "engineering director".
- **Decision:** standardize on **"Dan Bruder | Engineering Director"**.
- Files: `root.html.heex` (`live_title default`), `home_live.ex` (`page_title`).

### 2. Sharing metadata (`root.html.heex` `<head>`)
Add, driven by assigns with sensible site-level fallbacks:
- `<meta name="description">` — from `@meta_description`, default to a site bio.
- Open Graph: `og:type`, `og:title`, `og:description`, `og:url`, `og:image`,
  `og:site_name`.
- Twitter card: `summary_large_image`, title, description, image.
- `<link rel="canonical">` and `og:url` — absolute URL from
  `BlogWeb.Endpoint.url()` + current path (via `@current_path`, assigned by a
  small `on_mount`/plug; fall back to base URL if absent).
- `og:image` — absolute URL to `/images/my-face-new.jpg` (existing asset).
- Post show sets `@meta_description` to a plain-text excerpt of the body.

New helper: `Blog.Content.excerpt/2` — strip markdown/HTML, collapse
whitespace, truncate to ~160 chars on a word boundary. Unit tested.

Current path: add `BlogWeb.CurrentPath` `on_mount` hook that assigns
`:current_path` from the `handle_params` URI, wired into both `live_session`s.
For non-live pages the canonical falls back to the base URL (acceptable).

### 3. Feeds + sitemap
- **Decision:** RSS 2.0 served at `/rss.xml` and `/feed.xml`; `/atom.xml`
  301-redirects to `/rss.xml`.
- `/sitemap.xml` — home + every published post.
- New `BlogWeb.FeedController` with `rss/2` and `sitemap/2`, rendered as XML
  strings (no template engine needed; build with iodata + `EEx`-free helpers).
- Items: title, absolute link, guid (= link), pubDate (RFC-822 from
  `published_at` at 00:00 UTC), and full rendered HTML body in
  `<content:encoded>` (CDATA).
- Routes live in a new pipeline that skips CSRF/layout, `accepts: ["xml"]`.
- `<link rel="alternate" type="application/rss+xml">` added to `<head>`.
- Controller test: `/rss.xml` returns 200, `application/rss+xml`, contains a
  published post title and is well-formed; `/atom.xml` redirects;
  `/sitemap.xml` returns 200 with the post URL.

## Tier 3 — design consolidation & accessibility

### 4. Accent color system (`app.css`)
- **Decision:** two-token warm/cool system via CSS custom properties in
  `:root`:
  - `--accent-heading` → `theme(colors.sky.200)` — ALL headings (drops the
    `teal-100` used for `.markdown-content` headings).
  - `--accent-link` / `--accent-link-hover` → `theme(colors.orange.200 / .300)`
    — ALL links (chrome links currently `blue-100→blue-300` move to orange, so
    links look the same everywhere).
  - `--accent-border` / `--accent-glow` → blue-200 / indigo-500 (unchanged),
    used only by interactive elements (see #5).
- Replace scattered utility usages with these variables. Headings that use
  `text-sky-200` inline in heex (hero, post titles, home) switch to a
  `.heading-accent` class or keep sky-200 (same value) — keep inline sky-200
  since it already equals the token; the consolidation is about *removing the
  teal divergence* and *unifying link color*. Blockquote/inline-code keep
  orange (now the single link/accent-warm color).

### 5. Remove glow from content images
- Split the `button, .snake, img { … }` rule.
- `button, .snake` keep the full treatment incl. `hover:shadow-indigo-500/90`
  glow (interactive).
- `img` gets `rounded-xl` + a subtle static border only — no colored shadow,
  no hover glow.

### 6. Accessibility
- Header avatar `<img>`: add `alt="Dan Bruder"`.
- Home post dates: replace `<label>` (form-control element, misused) with
  `<time datetime=…>`.
- Date contrast: `text-gray-500` → `text-zinc-400` (higher contrast on the
  zinc-900 background) for post dates on home and show.

## Testing
- `mix test` green.
- New: `Blog.Content.excerpt/2` unit tests; `FeedController` request tests.
- Manual/`/run` check: home + a post page render, feed validates, OG tags
  present in `curl` of the rendered `<head>`.

## Out of scope (deferred to a later IA pass)
Selected-writing section, `/notes` split, Projects section, homepage
hierarchy/excerpts redesign, about-page rewrite, publishing drafts, books page.
