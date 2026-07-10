defmodule Blog.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :body, :text, null: false, default: ""
      add :kind, :string, null: false, default: "post"
      add :published, :boolean, null: false, default: true
      add :category, :string
      add :tags, :string
      add :published_at, :date

      timestamps()
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:kind, :published, :published_at])
  end
end
