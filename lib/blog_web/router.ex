defmodule BlogWeb.Router do
  use BlogWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {BlogWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(BlogWeb.Plugs.RedirectReclassifiedNote)
  end

  pipeline :require_admin do
    plug(BlogWeb.AdminAuth)
  end

  pipeline :feeds do
    plug(:accepts, ["xml"])
  end

  scope "/", BlogWeb do
    pipe_through(:browser)

    live_session :public,
      on_mount: [{BlogWeb.PresenceTracker, :track}, {BlogWeb.CurrentPath, :default}] do
      live("/", HomeLive, :index)
      live("/writing", WritingLive, :index)
      live("/blog/:slug", PostLive.Show, :show)
      live("/notes", NoteLive.Index, :index)
      live("/notes/:slug", PostLive.Show, :show)
      live("/games", GamesLive.Index, :index)
      live("/games/snake", SnakeLive, :index)
      live("/games/sand", SandLive, :index)
      live("/podcasts", PodcastLive.Index, :index)
      live("/projects", ProjectLive.Index, :index)
    end

    get("/snake", RedirectController, :snake)
    get("/rpsb", FunController, :rpsb)

    get("/admin/login", AdminSessionController, :new)
    post("/admin/login", AdminSessionController, :create)
    delete("/admin/logout", AdminSessionController, :delete)
  end

  scope "/", BlogWeb do
    pipe_through(:feeds)

    get("/rss.xml", FeedController, :rss)
    get("/feed.xml", FeedController, :rss)
    get("/atom.xml", FeedController, :atom)
    get("/sitemap.xml", FeedController, :sitemap)
  end

  scope "/admin", BlogWeb.Admin, as: :admin do
    pipe_through([:browser, :require_admin])

    live_session :admin,
      on_mount: {BlogWeb.AdminAuth, :ensure_admin} do
      live("/", PostIndexLive, :index)
      live("/posts/new", PostFormLive, :new)
      live("/posts/:id/edit", PostFormLive, :edit)
      live("/viewers", PresenceLive, :index)
    end
  end
end
