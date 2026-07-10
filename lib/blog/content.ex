defmodule Blog.Content do
  @moduledoc """
  Context for blog posts and simple markdown pages (about, etc.), all
  backed by the single `posts` table.
  """

  import Ecto.Query, warn: false
  alias Blog.Repo
  alias Blog.Content.Post

  def list_published_posts(limit \\ nil) do
    query =
      from(p in Post,
        where: p.kind == "post" and p.published == true,
        order_by: [desc: p.published_at, desc: p.id]
      )

    query = if limit, do: from(p in query, limit: ^limit), else: query
    Repo.all(query)
  end

  def list_posts do
    Repo.all(from(p in Post, order_by: [desc: p.published_at, desc: p.id]))
  end

  def get_post!(id), do: Repo.get!(Post, id)

  def get_by_slug(slug) do
    Repo.get_by(Post, slug: slug)
  end

  def get_published_by_slug(slug) do
    Repo.get_by(Post, slug: slug, published: true)
  end

  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  def any_posts? do
    Repo.exists?(Post)
  end

  @doc "Renders a post's markdown body to HTML."
  def render_body(%Post{body: body}) do
    case Earmark.as_html(body || "") do
      {:ok, html, _} -> html
      {:error, html, _errors} -> html
    end
  end
end
