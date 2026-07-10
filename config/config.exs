import Config

config :blog,
  ecto_repos: [Blog.Repo],
  generators: [timestamp_type: :utc_datetime]

config :blog, Blog.Repo,
  adapter: Ecto.Adapters.SQLite3,
  pool_size: 5

config :blog, BlogWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BlogWeb.ErrorHTML, json: BlogWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Blog.PubSub,
  live_view: [signing_salt: "blogLiveViewSalt"]

config :esbuild,
  version: "0.21.5",
  blog: [
    args:
      ~w(js/app.js --bundle --target=es2020 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  blog: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/css/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

import_config "#{config_env()}.exs"
