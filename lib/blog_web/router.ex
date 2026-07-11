defmodule BlogWeb.Router do
  use BlogWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {BlogWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :require_admin do
    plug(BlogWeb.AdminAuth)
  end

  scope "/", BlogWeb do
    pipe_through(:browser)

    live("/", HomeLive, :index)
    live("/blog/:slug", PostLive.Show, :show)

    get("/rpsb", FunController, :rpsb)
    live("/snake", SnakeLive, :index)

    get("/admin/login", AdminSessionController, :new)
    post("/admin/login", AdminSessionController, :create)
    delete("/admin/logout", AdminSessionController, :delete)
  end

  scope "/admin", BlogWeb.Admin, as: :admin do
    pipe_through([:browser, :require_admin])

    live_session :admin,
      on_mount: {BlogWeb.AdminAuth, :ensure_admin} do
      live("/", PostIndexLive, :index)
      live("/posts/new", PostFormLive, :new)
      live("/posts/:id/edit", PostFormLive, :edit)
    end
  end
end
