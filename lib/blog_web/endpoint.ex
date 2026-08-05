defmodule BlogWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :blog

  @code_reloading? Application.compile_env(:blog, :dev_routes, false)

  @session_options [
    store: :cookie,
    key: "_blog_key",
    signing_salt: "blogSessSalt",
    same_site: "Lax",
    # Long-lived on purpose: `:admin_seen` (see AdminSessionController) rides
    # in this same cookie and needs to survive browser restarts so analytics
    # can keep excluding the admin's own traffic indefinitely, not just for
    # the current session.
    max_age: 60 * 60 * 24 * 365 * 5
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, :x_headers, session: @session_options]]
  )

  socket("/socket", BlogWeb.UserSocket, websocket: true, longpoll: false)

  plug(Plug.Static,
    at: "/",
    from: :blog,
    gzip: true,
    only: BlogWeb.static_paths()
  )

  if @code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(BlogWeb.Router)
end
