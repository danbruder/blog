import Config

config :blog, Blog.Repo,
  database: Path.expand("../blog_dev.db", __DIR__),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :blog, BlogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev-only-secret-key-base-not-for-production-use-0123456789abcdef",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:blog, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:blog, ~w(--watch)]}
  ]

config :blog, BlogWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/blog_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Dev-only admin password for /admin/login. In prod this comes from the
# ADMIN_PASSWORD environment variable (see runtime.exs).
config :blog, :admin_password, "admin"

config :blog, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
