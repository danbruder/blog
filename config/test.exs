import Config

config :blog, Blog.Repo,
  database: Path.expand("../blog_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  busy_timeout: 10_000

config :blog, BlogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-only-secret-key-base-not-for-production-use-0123456789abcdef",
  server: false

config :blog, :admin_password, "test-admin-password"

# Avoid real network calls to the geo-IP lookup service during tests.
config :blog, :geoip_enabled, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
