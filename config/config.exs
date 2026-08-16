import Config

config :blog,
  ecto_repos: [Blog.Repo],
  generators: [timestamp_type: :utc_datetime]

config :blog, Blog.Repo,
  adapter: Ecto.Adapters.SQLite3,
  pool_size: 5,
  journal_mode: :wal,
  busy_timeout: 5_000

# One place `Blog.Kudos.today_range/1` and the Cron plugin below both read,
# so the digest's "today" window and the schedule it runs on can never
# drift apart. `Blog.Kudos` needs a real IANA database (not just
# `Calendar.UTCOnlyTimeZoneDatabase`, Elixir's default) to convert between
# this and UTC -- see the `:tz` dep and the `time_zone_database` config
# below.
kudos_digest_timezone = "America/New_York"

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :blog, :kudos_digest_timezone, kudos_digest_timezone
# Overridden per-environment (recipient in particular -- see runtime.exs
# for prod); this default just keeps dev/test working out of the box.
config :blog, :kudos_digest_to, "danbruder@hey.com"

config :blog, Oban,
  engine: Oban.Engines.Lite,
  repo: Blog.Repo,
  queues: [default: 5],
  plugins: [
    {Oban.Plugins.Cron,
     timezone: kudos_digest_timezone,
     crontab: [
       # "End of day" for the kudos digest -- see Blog.Kudos.DailyDigestWorker.
       {"0 21 * * *", Blog.Kudos.DailyDigestWorker}
     ]}
  ]

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
      ~w(js/app.js js/paintWorklet.js --bundle --target=es2020 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --external:/assets/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  sea: [
    args:
      ~w(js/sea/index.js --bundle --format=esm --target=es2020 --outdir=../priv/static/assets/js/sea),
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
