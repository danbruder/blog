# danbruder.com

A Phoenix + LiveView blog/CMS backed by SQLite. Posts (and a couple of simple
pages: about, secret santa list) live in the database and are edited through
a small `/admin` LiveView CMS, instead of being generated from markdown files
at build time.

The old Zola static-site content has been migrated in: `priv/legacy_content`
holds the original markdown, and `Blog.ContentImporter` (see
`priv/repo/seeds.exs`) parses it into `posts` rows the first time the app
boots against an empty database.

## Local development

```bash
mix deps.get
mix ecto.setup      # create db, run migrations, import legacy content
mix phx.server       # http://localhost:4000
```

Set `ADMIN_PASSWORD` (or use the `config :blog, :admin_password` dev/test
default) to log in at `/admin/login`.

## Deploying

This app is a plain Elixir release (see `Dockerfile`) that reads
`DATABASE_PATH`, `SECRET_KEY_BASE`, `ADMIN_PASSWORD`, and `PHX_HOST` from the
environment, and expects its SQLite file on a persistent volume at
`/data/app.db` — this matches
[litehouse](https://github.com/danbruder/litehouse)'s app-volume convention,
so `lh create blog --repo <owner>/blog` + `git push` is the intended way to
ship it.

First-party analytics (page views and other visitor events, see
`Blog.Analytics`) are stored in a DuckDB file that defaults to
`analytics.duckdb` next to the SQLite file on that same backed-up volume;
override the location with `ANALYTICS_PATH` if needed.

## Ideas / not-yet-done

- Split the old "blog" posts (mostly small learnings/notes) into a lighter,
  non-blog format
- Tags/category browsing (data is imported, but there's no UI for it yet)
- Allowing developer profile to run on iOS build
- Adding image resizing to a route in Elixir

## Todos from design/content review (2026-07)

Quick fixes:

- [ ] Fix the typo in the newest post title: "Advice for new mangers" →
  "managers" (in `priv/legacy_content/posts/advice-for-new-managers.md` AND
  via `/admin` on prod, since the seeder won't overwrite existing rows)
- [x] Make the title consistent everywhere: `<title>`/page titles say
  "Software Engineering Manager", hero says "engineering director" — use
  the current title (Director) in all places (now "Dan Bruder | Engineering
  Director" everywhere)

Content:

- [ ] Rewrite the about page: update stale numbers ("14 years", frontmatter
  dated 2017), add contact info + GitHub/LinkedIn/resume links (currently
  none exist anywhere on the site), surface the Software Unscripted podcast
  link more prominently
- [ ] Add a "Selected writing" section (3–5 hand-picked essays) at the top
  of the homepage; move TIL-style notes to a lighter `/notes` list
- [ ] Add a "Projects" section: this blog (Phoenix/LiveView CMS),
  multiplayer snake + live presence, litehouse — with GitHub links
- [ ] Finish and publish one flagship draft: "Never Rewrite Again™",
  "How I Make Software" (both empty drafts), or the Insta360 stitching
  war story (`insta-360.md`, half-written braindump)
- [ ] Update the books page (last updated 2021)
- [ ] Consider writing about how the team uses AI tooling

Sharing / discoverability:

- [x] Add meta description, Open Graph + Twitter card tags, and og:image to
  `root.html.heex` (post pages set a description from a body excerpt; canonical
  + og:url are per-page via a `CurrentPath` on_mount hook; see `BlogWeb.SEO`)
- [x] Add an Atom/RSS feed route (live site 404s on /atom.xml and /rss.xml)
  and a sitemap (RSS 2.0 at `/rss.xml` + `/feed.xml`, `/atom.xml` 301s to it,
  `/sitemap.xml`; see `BlogWeb.FeedController`)

Design:

- [x] Consolidate accent colors (links are blue-100/orange-200 depending on
  context; headings sky-200/teal-100) into one system in `app.css`
  (two CSS vars: `--accent-heading` sky-200 for all headings, `--accent-link`
  orange for all links)
- [x] Remove the glow border/shadow from content images (`button, .snake,
  img` rule) — keep it for interactive elements only
- [ ] Homepage hierarchy: "Latest Posts" is a gray h4 while post titles are
  huge blue h2s; add one-line excerpts under featured posts
- [x] Accessibility: alt text on the header avatar, replace `<label>` used
  for post dates, bump gray-500 date contrast (dates now `<time>` at zinc-400)
- [ ] Move the "have a go at snake" CTA off every post into the footer or a
  `/fun` page
