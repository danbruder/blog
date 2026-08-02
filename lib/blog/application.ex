defmodule Blog.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BlogWeb.Telemetry,
      Blog.Repo,
      {Phoenix.PubSub, name: Blog.PubSub},
      BlogWeb.Presence,
      Blog.GeoIP,
      {Blog.Analytics, Application.fetch_env!(:blog, Blog.Analytics)},
      Blog.SnakeGame,
      Blog.SandGame,
      BlogWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Blog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BlogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
