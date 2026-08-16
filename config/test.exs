import Config

config :blog, Blog.Repo,
  database: Path.expand("../blog_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  # Async tests each hold their own sandboxed connection for the test's
  # duration, so the pool needs enough room for ExUnit's max_cases (one
  # per scheduler pair) or extra tests queue for a checkout and time out
  # while others are still (correctly) blocking on busy_timeout below.
  pool_size: 20,
  busy_timeout: 5_000

config :blog, BlogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-only-secret-key-base-not-for-production-use-0123456789abcdef",
  server: false

config :blog, :admin_password, "test-admin-password"

# Avoid real network calls to the geo-IP lookup service during tests.
config :blog, :geoip_enabled, false

config :blog, Blog.Analytics, path: :memory

# Don't run Cron or process jobs in the background during tests -- tests
# that care exercise Blog.Kudos.DailyDigestWorker.perform/1 directly.
config :blog, Oban, testing: :manual

config :blog, :site_url, "http://localhost:4002"

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
