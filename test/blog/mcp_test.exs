defmodule Blog.MCPTest do
  use Blog.DataCase, async: true

  alias Blog.Content
  alias Blog.MCP

  @valid_attrs %{
    title: "Hello world",
    slug: "hello-world",
    body: "**hi**",
    kind: "post",
    published: true,
    published_at: nil
  }

  describe "list_posts" do
    test "returns summaries, without the body, for every kind by default" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, [summary]} = MCP.call_tool("list_posts", %{})
      assert summary.id == post.id
      assert summary.slug == "hello-world"
      refute Map.has_key?(summary, :body)
    end

    test "filters by kind" do
      {:ok, _post} = Content.create_post(@valid_attrs)
      {:ok, note} = Content.create_post(%{@valid_attrs | slug: "a-note", kind: "note"})

      assert {:ok, [summary]} = MCP.call_tool("list_posts", %{"kind" => "note"})
      assert summary.id == note.id
    end

    test "filters by status" do
      {:ok, published} = Content.create_post(@valid_attrs)
      {:ok, draft} = Content.create_post(%{@valid_attrs | slug: "draft", published: false})

      assert {:ok, [summary]} = MCP.call_tool("list_posts", %{"status" => "draft"})
      assert summary.id == draft.id

      assert {:ok, [summary]} = MCP.call_tool("list_posts", %{"status" => "published"})
      assert summary.id == published.id
    end

    test "rejects an invalid status even with no posts in the database" do
      assert {:error, message} = MCP.call_tool("list_posts", %{"status" => "bogus"})
      assert message =~ "invalid status"
    end
  end

  describe "get_post" do
    test "returns the full post, including body, by id" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, result} = MCP.call_tool("get_post", %{"id" => post.id})
      assert result.body == "**hi**"
    end

    test "returns the full post by slug" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, result} = MCP.call_tool("get_post", %{"slug" => "hello-world"})
      assert result.id == post.id
    end

    test "errors when neither id nor slug is given" do
      assert {:error, "id or slug is required"} = MCP.call_tool("get_post", %{})
    end

    test "errors when nothing matches" do
      assert {:error, message} = MCP.call_tool("get_post", %{"slug" => "nope"})
      assert message =~ "no post with slug"
    end
  end

  describe "create_post" do
    test "creates an unpublished draft by default" do
      assert {:ok, result} = MCP.call_tool("create_post", %{"title" => "My New Post"})

      assert result.title == "My New Post"
      assert result.slug == "my-new-post"
      assert result.published == false
      assert result.kind == "post"
    end

    test "honors an explicit slug, kind, and published flag" do
      assert {:ok, result} =
               MCP.call_tool("create_post", %{
                 "title" => "A Note",
                 "slug" => "custom-slug",
                 "kind" => "note",
                 "body" => "hi",
                 "published" => true,
                 "published_at" => "2026-01-15"
               })

      assert result.slug == "custom-slug"
      assert result.kind == "note"
      assert result.published == true
      assert result.published_at == "2026-01-15"
    end

    test "requires a title" do
      assert {:error, "title is required"} = MCP.call_tool("create_post", %{})
    end

    test "surfaces a changeset error for a duplicate slug" do
      {:ok, _} = Content.create_post(@valid_attrs)

      assert {:error, message} =
               MCP.call_tool("create_post", %{"title" => "Hello world", "slug" => "hello-world"})

      assert message =~ "slug"
    end
  end

  describe "update_post" do
    test "updates only the given fields" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, result} =
               MCP.call_tool("update_post", %{"id" => post.id, "title" => "New title"})

      assert result.title == "New title"
      assert result.slug == "hello-world"
    end

    test "renames the slug via new_slug" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, result} =
               MCP.call_tool("update_post", %{"slug" => post.slug, "new_slug" => "renamed"})

      assert result.slug == "renamed"
    end

    test "can flip published to false" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, result} =
               MCP.call_tool("update_post", %{"id" => post.id, "published" => false})

      assert result.published == false
    end

    test "errors when the post doesn't exist" do
      assert {:error, message} = MCP.call_tool("update_post", %{"id" => 999_999, "title" => "x"})
      assert message =~ "no post with id"
    end
  end

  describe "publish_post" do
    test "publishes a draft and defaults published_at to today" do
      {:ok, post} = Content.create_post(%{@valid_attrs | published: false, published_at: nil})

      assert {:ok, result} = MCP.call_tool("publish_post", %{"id" => post.id})
      assert result.published == true
      assert result.published_at == Date.to_iso8601(Date.utc_today())
    end

    test "accepts an explicit published_at" do
      {:ok, post} = Content.create_post(%{@valid_attrs | published: false})

      assert {:ok, result} =
               MCP.call_tool("publish_post", %{"id" => post.id, "published_at" => "2020-01-01"})

      assert result.published_at == "2020-01-01"
    end
  end

  describe "unpublish_post" do
    test "sets published to false without touching other fields" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, result} = MCP.call_tool("unpublish_post", %{"slug" => post.slug})
      assert result.published == false
      assert result.title == post.title
    end
  end

  describe "delete_post" do
    test "deletes the post" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, %{deleted: true, id: id}} = MCP.call_tool("delete_post", %{"id" => post.id})
      assert id == post.id
      assert Content.get_post(post.id) == nil
    end
  end

  describe "preview_post" do
    test "renders a given markdown body" do
      assert {:ok, %{html: html}} = MCP.call_tool("preview_post", %{"body" => "**hi**"})
      assert html =~ "<strong>hi</strong>"
    end

    test "renders an existing post's body when no body is given" do
      {:ok, post} = Content.create_post(@valid_attrs)

      assert {:ok, %{html: html}} = MCP.call_tool("preview_post", %{"id" => post.id})
      assert html =~ "<strong>hi</strong>"
    end
  end

  test "call_tool/2 errors on an unknown tool name" do
    assert {:error, "unknown tool: nope"} = MCP.call_tool("nope", %{})
  end

  test "tools/0 returns a schema for every dispatchable tool" do
    names = MCP.tools() |> Enum.map(& &1.name)

    assert names == [
             "list_posts",
             "get_post",
             "create_post",
             "update_post",
             "publish_post",
             "unpublish_post",
             "delete_post",
             "preview_post"
           ]
  end
end
