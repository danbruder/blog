defmodule Blog.Release do
  @moduledoc """
  Tasks run via `bin/blog eval` in production, where Mix is unavailable.
  """

  @app :blog

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          Blog.ContentImporter.seed()
        end)
    end
  end

  def migrate_and_seed do
    migrate()
    seed()
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
