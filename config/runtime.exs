import Config

if System.get_env("PHX_SERVER") do
  config :blog, BlogWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /data/blog.db
      """

  config :blog, Blog.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # Lives on the same persistent, backed-up volume as the SQLite file
  # (e.g. /data/analytics.duckdb next to /data/app.db), unless overridden.
  config :blog, Blog.Analytics,
    path:
      System.get_env("ANALYTICS_PATH") ||
        Path.join(Path.dirname(database_path), "analytics.duckdb")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :blog, :site_url, "https://#{host}"

  # Both optional: without RESEND_API_KEY/RESEND_FROM_EMAIL configured,
  # Blog.Resend.send_email/1 just returns {:error, :missing_api_key} (or
  # :missing_from_address) instead of raising, so a blog without kudos
  # email set up still boots -- see Blog.Kudos.deliver_digest/2.
  config :blog, Blog.Resend,
    api_key: System.get_env("RESEND_API_KEY"),
    from: System.get_env("RESEND_FROM_EMAIL")

  config :blog, :kudos_digest_to, System.get_env("KUDOS_DIGEST_TO_EMAIL") || "danbruder@hey.com"

  config :blog,
         :admin_password,
         System.get_env("ADMIN_PASSWORD") ||
           raise("""
           environment variable ADMIN_PASSWORD is missing.
           Set it to the password you'll use to log in to /admin.
           """)

  config :blog, BlogWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    # Allow LiveView sockets from every host this app is reachable at. Listing
    # them explicitly (rather than relying on the :url host default) lets us
    # move PHX_HOST to danbruder.com without breaking the derived
    # blog.lh.danbruder.com host, and keeps both working during the cutover.
    check_origin: [
      "https://danbruder.com",
      "https://www.danbruder.com",
      "https://blog.lh.danbruder.com",
      "//#{host}"
    ],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end
