defmodule Blog.Repo.Migrations.ReclassifyTilPostsAsNotes do
  use Ecto.Migration

  import Ecto.Query

  # See docs/superpowers/specs/2026-07-11-notes-vs-posts-design.md for the
  # rationale behind this split. This is the same list of 36 slugs as
  # BlogWeb.Plugs.RedirectReclassifiedNote, inlined rather than referenced so
  # this migration stays correct even if that module changes later.
  @moved_slugs ~w(
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
  )

  def up do
    from(p in "posts", where: p.slug in ^@moved_slugs)
    |> repo().update_all(set: [kind: "note"])
  end

  def down do
    from(p in "posts", where: p.slug in ^@moved_slugs)
    |> repo().update_all(set: [kind: "post"])
  end
end
