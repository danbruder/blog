defmodule Blog.ContentTest do
  use Blog.DataCase, async: true

  alias Blog.Content

  @valid_attrs %{
    title: "Hello world",
    slug: "hello-world",
    body: "**hi**",
    kind: "post",
    published: true
  }

  test "create_post/1 with valid data creates a post" do
    assert {:ok, post} = Content.create_post(@valid_attrs)
    assert post.slug == "hello-world"
  end

  test "create_post/1 rejects a duplicate slug" do
    assert {:ok, _} = Content.create_post(@valid_attrs)
    assert {:error, changeset} = Content.create_post(@valid_attrs)
    assert "has already been taken" in errors_on(changeset).slug
  end

  test "list_published_posts/1 excludes drafts and pages" do
    {:ok, published} = Content.create_post(@valid_attrs)
    {:ok, _draft} = Content.create_post(%{@valid_attrs | slug: "draft-post", published: false})
    {:ok, _page} = Content.create_post(%{@valid_attrs | slug: "about", kind: "page"})

    slugs = Content.list_published_posts() |> Enum.map(& &1.slug)

    assert slugs == [published.slug]
  end

  test "list_published_notes/1 returns only notes, excluding posts and pages" do
    {:ok, note} = Content.create_post(%{@valid_attrs | slug: "a-note", kind: "note"})
    {:ok, _post} = Content.create_post(@valid_attrs)

    {:ok, _draft_note} =
      Content.create_post(%{@valid_attrs | slug: "draft-note", kind: "note", published: false})

    slugs = Content.list_published_notes() |> Enum.map(& &1.slug)

    assert slugs == [note.slug]
  end

  test "render_body/1 renders markdown to html" do
    {:ok, post} = Content.create_post(@valid_attrs)
    assert Content.render_body(post) =~ "<strong>hi</strong>"
  end

  test "get_published_by_slug/1 returns nil for drafts" do
    {:ok, _} = Content.create_post(%{@valid_attrs | published: false})
    assert Content.get_published_by_slug("hello-world") == nil
  end

  test "excerpt/2 strips markdown and collapses whitespace" do
    body = "# A heading\n\nSome **bold** text with a [link](http://x) and `code`."
    excerpt = Content.excerpt(body)

    refute excerpt =~ "#"
    refute excerpt =~ "**"
    refute excerpt =~ "["
    assert excerpt =~ "Some bold text"
    assert excerpt =~ "link"
  end

  test "excerpt/2 strips raw HTML tags found in legacy posts" do
    body = ~s(<img class="portrait" src="/images/x.jpg"/> Hello there.)
    excerpt = Content.excerpt(body)

    refute excerpt =~ "<"
    refute excerpt =~ "img"
    assert excerpt =~ "Hello there."
  end

  test "excerpt/2 truncates on a word boundary with an ellipsis" do
    body = String.duplicate("word ", 100)
    excerpt = Content.excerpt(body, 40)

    assert String.length(excerpt) <= 41
    assert String.ends_with?(excerpt, "…")
    refute excerpt =~ ~r/\Sword…\z/
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
