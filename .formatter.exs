[
  import_deps: [:ecto, :phoenix, :phoenix_live_view],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/repo/seeds.exs"
  ]
]
