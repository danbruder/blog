import Config

config :blog, Blog.Repo,
  database: Path.expand("../blog_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

config :blog, BlogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-only-secret-key-base-not-for-production-use-0123456789ab",
  server: false

config :blog, :admin_password, "test-admin-password"

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
