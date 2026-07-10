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

## Ideas / not-yet-done

- Split the old "blog" posts (mostly small learnings/notes) into a lighter,
  non-blog format
- Tags/category browsing (data is imported, but there's no UI for it yet)
- Allowing developer profile to run on iOS build
- Adding image resizing to a route in Elixir
