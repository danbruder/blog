defmodule Blog.Content.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(post page note)

  schema "posts" do
    field(:title, :string)
    field(:slug, :string)
    field(:body, :string, default: "")
    field(:kind, :string, default: "post")
    field(:published, :boolean, default: true)
    field(:category, :string)
    field(:tags, :string)
    field(:published_at, :date)

    timestamps()
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :slug, :body, :kind, :published, :category, :tags, :published_at])
    |> validate_required([:title, :slug, :kind, :published])
    |> validate_inclusion(:kind, @kinds)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "must be lowercase letters, numbers, and hyphens only"
    )
    |> unique_constraint(:slug)
  end

  def kinds, do: @kinds
end
