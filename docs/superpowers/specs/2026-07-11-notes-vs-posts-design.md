# Split posts from notes/TILs

Implements the "split the old 'blog' posts (mostly small learnings/notes)
into a lighter, non-blog format" item from the README's ideas list and the
"move TIL-style notes to a lighter `/notes` list" item from the 2026-07
content review todos.

Decisions below were made with the user away (no response to the naming
question), using the recommended option and reasonable judgment. Flagged for
review — the slug classification table especially.

## Naming

**Decision:** call it **"Notes"**. `kind: "note"` in the schema, `/notes`
route. This is what the README's todo list already called it; lowest-risk
default given no response on the question. Easy to rename later if
`Dan` prefers "TIL" or something else — it's a string constant + a route
prefix, not a deep architectural choice.

## Mechanism: reuse `posts`, don't add a table

`Blog.Content.Post` already has a `kind` field (`"post"` | `"page"`) that
exists for exactly this purpose — distinguishing content shapes that share
the same title/slug/body/date structure. Posts and notes are structurally
identical (both are markdown + a date), so:

- **Decision:** add `"note"` as a third `kind` value. `Post.kinds/0` becomes
  `~w(post page note)`. No new schema, no migration of table structure —
  just a data migration to reclassify existing rows (see below).
- Rejected: a separate `notes` table/schema. Would duplicate the admin
  CRUD forms, changesets, and context functions for no real benefit — the
  only difference between a post and a note is which list it shows up in
  and whether the newsletter/snake footer renders.

## Content context (`lib/blog/content.ex`)

- Generalize `list_published_posts/1` into a private kind-aware query
  helper; keep `list_published_posts/1` as `kind: "post"` for backward
  compatibility with `HomeLive`, add `list_published_notes/1` as
  `kind: "note"`.
- `list_posts/0` (admin, all kinds) is unaffected.

## Routes & views

- `/notes` → new `BlogWeb.NoteLive.Index` — a deliberately lighter list than
  the homepage: just title + date per row, no hero/intro copy, no featured
  styling. Reuses the homepage's list-row markup/classes where reasonable.
- `/notes/:slug` → reuse `BlogWeb.PostLive.Show` unchanged. It already
  renders the newsletter signup box and the "have a go at snake" footer
  only `:if={@post.kind == "post"}`, so notes naturally get neither. No
  code change needed here beyond the route.
- Homepage (`HomeLive`): unchanged post list; add one small text link (e.g.
  under "Latest Posts") to `/notes` so the split is discoverable. Not
  attempting the README's separate "Selected writing" curation item here —
  out of scope.

## Redirects: old `/blog/:slug` → `/notes/:slug`

Each of the 36 reclassified slugs currently has an indexed/bookmarked/
linked-to `/blog/:slug` URL that must keep working. **Decision:** a genuine
HTTP 301 via a plug, not a LiveView `redirect/2` call in `mount/3` — and
scoped to exactly those 36 slugs (a static list), not a general "any
note-kind slug" rule. Dan only cares about preserving the old URLs that
already exist; new notes are created as notes from the start and never had
a `/blog/:slug` URL to preserve, so there's nothing to redirect for them.

Why not just redirect inside `PostLive.Show`'s `mount/3` (the pattern
already used there for the not-found case)? Two reasons:
- `Phoenix.LiveView.redirect/2` has no way to set the response status, so a
  dead-render hit (a crawler or a browser opening the bare URL) gets a 302,
  not a 301 — bad for search engines eventually consolidating onto the new
  URL.
- Getting a real 301 requires a plug, and adding that plug to only the
  `/blog/:slug` route would need pulling it into its own `live_session`,
  which would break same-session live-navigation (SPA-style, no full page
  reload) between the homepage and *every* post, not just the reclassified
  ones — a regression to the common case for the sake of the rare one.

Instead: a small plug appended to the existing `:browser` pipeline (used by
all public routes) that matches on a static list of the 36 migrated slugs —
no database lookup, no dependency on `Blog.Content`:

```elixir
defmodule BlogWeb.Plugs.RedirectReclassifiedNote do
  import Plug.Conn

  # The slugs moved from kind "post" to kind "note" in the 2026-07 notes
  # migration (see docs/superpowers/specs/2026-07-11-notes-vs-posts-design.md).
  # Old /blog/:slug links for these 301 to their new /notes/:slug location.
  @moved_slugs ~w(
    typeerror-require-is-not-a-function-webpack-faunadb
    installing-react-easy-chart
    ...
    where-is-info-plist-in-swiftui-project
  )

  def init(opts), do: opts

  def call(%Plug.Conn{path_info: ["blog", slug]} = conn, _opts) when slug in @moved_slugs do
    conn
    |> put_status(:moved_permanently)
    |> Phoenix.Controller.redirect(to: "/notes/#{slug}")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
```

Every other route (`/`, `/blog/:slug` for a real post, `/snake`, `/notes`,
`/notes/:slug`, `/admin/*`) falls through the guard clause unchanged — no
DB query on the common path, no `live_session` restructuring, no change to
existing navigation behavior. The `@moved_slugs` list is exactly the "→
`note`" list below; if that list changes before implementation, update both
together.

## Admin (`lib/blog_web/live/admin/`)

- `PostFormLive`: add `{"Note", "note"}` to the Kind `<select>` options.
- `PostIndexLive`: the per-row public path currently hardcoded as
  `/blog/{post.slug}` becomes kind-aware: `/blog/{slug}` for `"post"`,
  `/notes/{slug}` for `"note"`; `"page"` rows keep showing a path-looking
  string but it isn't a live link today (pages have no public route yet —
  pre-existing gap, not fixing here).

## Content importer (`lib/blog/content_importer.ex`)

- Add a `notes_dir/0` (`priv/legacy_content/notes`) and
  `import_dir(notes_dir(), "note")` alongside the existing posts/pages
  import, so a fresh database (new contributor, CI, etc.) seeds notes
  correctly without needing the data migration below.
- The corresponding 36 markdown files (list below) move from
  `priv/legacy_content/posts/` to `priv/legacy_content/notes/` in the same
  change.

## Reclassifying existing data

The importer only inserts rows for slugs that don't already exist — it
never updates a row's `kind` after the fact. Since dev/prod databases
already have these 50 rows seeded as `kind: "post"`, moving the markdown
files alone would do nothing there. **Decision:** a one-time Ecto migration
that runs `UPDATE posts SET kind = 'note' WHERE slug IN (...)` for the note
slugs.

### Classification rule

Split by content shape, not by category tag (categories are inconsistent —
plenty of reflective posts have a tech category like "Backend"):

- **Note**: procedural how-to, error-message lookup, single-fact reference
  ("How to X", "What is X", verbatim error strings, "X vs Y" comparisons).
- **Post**: reflective/narrative/opinion piece, curated link roundup, or
  essay — even if it also happens to carry a tech category tag.

### Classification table

**→ `note`** (36 slugs, moving to `priv/legacy_content/notes/`):

```
typeerror-require-is-not-a-function-webpack-faunadb
installing-react-easy-chart
installing-golang-1-9-on-raspberry-pi-3b
reload-environment-variables-on-windows
find-the-pid-of-a-process-by-specific-port
how-to-delete-a-git-tag
syntax-checking-in-vim-for-rust
set-up-correct-node-version-on-netlify
creating-a-paginated-blog-list-in-gatsbyjs
error-22001-string-data-right-truncation-value-too-long-for-type-character
how-to-use-elixirs-with-statement
example-using-dynamic-supervision-in-elixir-otp
running-specific-tests-in-elixir
free-up-space-by-removing-node-modules-recursively
default-value-for-a-field-in-changeset-use-ecto-schema-default
add-a-twitter-share-link-to-a-gatsby-blog
is-tsop6-the-same-as-sot23-6
infusionsoft-how-to-find-a-list-of-contacts-that-finished-a-sequence
what-is-the-alpine-equivalent-to-build-essential
store-json-blob-in-postgres-with-diesel
elm-compiler-map-given-key-is-not-an-element-in-the-map
pattern-matching-multiple-variants-in-rust
rust-enums-as-constructors
using-any-to-bind-a-where-in-diesel-sql-query
using-a-shared-future-to-wait-on-a-remote-resource-from-multiple-tasks-in
how-to-return-a-warp-filter-from-a-function-in-rust
enable-vim-mode-in-xcode-13
how-to-create-a-postgres-database-that-has-an-upper-case-letter-in-the-name
invalid-tls-option-server-name-indication
what-is-cte-in-postgres
delete-files-older-than-7-days-with-bash
difference-between-debouncing-and-throttling-rxjs
creating-a-dynamic-background-image-with-css-painting-api
js-equivalent-of-jquery-ready
elixir-ls-and-coc-elixir-setup-on-macos
where-is-info-plist-in-swiftui-project
```

**Stays `post`** (14 slugs, unchanged):

```
book                                                     - "Books" personal essay/list
aws-appsync-first-impressions                            - opinion/first-impressions piece
using-tachyons-is-a-huge-productivity-boost               - opinion piece
what-ive-learned-from-sashko-stubailo-apollo-meteor        - reflection
reflections-on-the-book-functional-web-development-...     - book reflection essay
elixir-otp-on-aws-lambda-reflections                       - reflection ("Reflections" in title)
how-i-make-software                                        - essay (draft)
picks-of-the-week-0                                         - curated link roundup
never-rewrite-again                                         - essay (draft)
how-i-run-a-team-of-remote-software-engineers-part-1-meetings - essay
picks-of-the-week-1                                         - curated link roundup
2024                                                         - yearly reflection (draft)
insta-360                                                    - war story (draft, title "TBD")
advice-for-new-managers                                     - essay
```

Two calls worth double-checking with Dan:
- `aws-appsync-first-impressions` and `elixir-otp-on-aws-lambda-reflections`
  read close to the note/post boundary — kept as posts because they're
  personal-take narratives rather than pure reference lookups, but a case
  could be made either way.
- `reflections-on-the-book-functional-web-development-with-elixir-otp-and-phoenix`
  and `book` (Books) are both book-related; kept as posts rather than notes
  since they're closer to the existing `/books` content idea than to a TIL.

## Testing

- `Blog.ContentTest`: `list_published_notes/1` returns only `kind: "note"`
  rows, in date-desc order, respects `published`.
- `BlogWeb.NoteLiveTest`: `/notes` renders note titles, not post titles.
- `BlogWeb.PostLiveShowTest` (if one exists, else add): a note's show page
  omits the newsletter form and snake footer.
- Migration test/smoke check: after running it, `Repo.aggregate` confirms
  36 rows have `kind: "note"`.
- `BlogWeb.Plugs.RedirectReclassifiedNoteTest` (or a router test): `GET
  /blog/:slug` for a slug in `@moved_slugs` returns 301 with `location:
  /notes/:slug`; for any other slug (a real post, a brand-new note not in
  the list, or nonexistent) it passes through untouched.

## Out of scope

- Homepage "Selected writing" hand-picked section (separate README item).
- Tag/category browsing UI (separate README item, pre-existing todo).
- Giving `kind: "page"` a public route (pre-existing gap, unrelated to this
  change).
