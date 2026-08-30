defmodule Blog.MCP do
  @moduledoc """
  Tool definitions and dispatch for the blog's MCP (Model Context Protocol)
  server, so a remote MCP client can create/edit/publish posts without going
  through the `/admin` UI. Deliberately free of any HTTP or JSON-RPC
  concerns -- see `BlogWeb.MCPController` for the transport, and
  `BlogWeb.Plugs.MCPAuth` for auth -- so tool behavior is testable as plain
  Elixir.

  Every tool returns `{:ok, result}` (a plain map, JSON-encodable by the
  controller) or `{:error, message}` (a human-readable string sent back to
  the calling model as a tool error, not a protocol error).
  """

  alias Blog.Content
  alias Blog.Content.Post

  @protocol_version "2024-11-05"

  def protocol_version, do: @protocol_version

  def server_info do
    %{name: "danbruder-blog", version: Application.spec(:blog, :vsn) |> to_string()}
  end

  def tools do
    [
      %{
        name: "list_posts",
        description:
          "List blog content (posts, notes, or pages), optionally filtered by kind and " <>
            "publish status. Returns summaries without the markdown body.",
        inputSchema: %{
          type: "object",
          properties: %{
            kind: %{
              type: "string",
              enum: Post.kinds(),
              description: "Only return content of this kind. Omit for all kinds."
            },
            status: %{
              type: "string",
              enum: ["all", "draft", "published"],
              description: "Filter by publish status. Defaults to \"all\"."
            }
          }
        }
      },
      %{
        name: "get_post",
        description:
          "Fetch a single post/note/page by id or slug, including its full markdown body.",
        inputSchema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Post id."},
            slug: %{type: "string", description: "Post slug."}
          }
        }
      },
      %{
        name: "create_post",
        description:
          "Create a new post/note/page. Defaults to an unpublished draft -- pass " <>
            "published: true to publish immediately, or call publish_post afterwards.",
        inputSchema: %{
          type: "object",
          properties: %{
            title: %{type: "string"},
            slug: %{
              type: "string",
              description:
                "Lowercase letters, numbers, and hyphens only. Derived from the title if omitted."
            },
            body: %{type: "string", description: "Markdown body."},
            kind: %{type: "string", enum: Post.kinds(), description: "Defaults to \"post\"."},
            category: %{type: "string"},
            tags: %{type: "string", description: "Comma-separated tags."},
            published: %{type: "boolean", description: "Defaults to false (draft)."},
            published_at: %{type: "string", description: "ISO 8601 date, e.g. 2026-08-30."}
          },
          required: ["title"]
        }
      },
      %{
        name: "update_post",
        description:
          "Update fields on an existing post/note/page, identified by id or slug. Only the " <>
            "fields you pass are changed.",
        inputSchema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Id of the post to update."},
            slug: %{type: "string", description: "Current slug of the post to update."},
            title: %{type: "string"},
            new_slug: %{type: "string", description: "New slug value to rename the post to."},
            body: %{type: "string"},
            kind: %{type: "string", enum: Post.kinds()},
            category: %{type: "string"},
            tags: %{type: "string"},
            published: %{type: "boolean"},
            published_at: %{type: "string", description: "ISO 8601 date."}
          }
        }
      },
      %{
        name: "publish_post",
        description:
          "Publish a draft, identified by id or slug. Sets published_at to today if it isn't " <>
            "already set.",
        inputSchema: %{
          type: "object",
          properties: %{
            id: %{type: "integer"},
            slug: %{type: "string"},
            published_at: %{type: "string", description: "ISO 8601 date to use instead of today."}
          }
        }
      },
      %{
        name: "unpublish_post",
        description:
          "Revert a post to draft (hidden from the public site) without deleting it, " <>
            "identified by id or slug.",
        inputSchema: %{
          type: "object",
          properties: %{id: %{type: "integer"}, slug: %{type: "string"}}
        }
      },
      %{
        name: "delete_post",
        description:
          "Permanently delete a post/note/page, identified by id or slug. This cannot be undone.",
        inputSchema: %{
          type: "object",
          properties: %{id: %{type: "integer"}, slug: %{type: "string"}}
        }
      },
      %{
        name: "preview_post",
        description:
          "Render markdown to the same HTML the site would show, for previewing a body " <>
            "(or an existing post's current body) before publishing.",
        inputSchema: %{
          type: "object",
          properties: %{
            body: %{
              type: "string",
              description: "Markdown to render. Takes precedence over id/slug."
            },
            id: %{type: "integer"},
            slug: %{type: "string"}
          }
        }
      }
    ]
  end

  def call_tool(name, args) when is_map(args) do
    dispatch(name, args)
  rescue
    e -> {:error, Exception.message(e)}
  end

  def call_tool(_name, _args), do: {:error, "arguments must be an object"}

  defp dispatch("list_posts", args), do: list_posts(args)

  defp dispatch("get_post", args),
    do: with({:ok, post} <- find_post(args), do: {:ok, post_detail(post)})

  defp dispatch("create_post", args), do: create_post(args)
  defp dispatch("update_post", args), do: update_post(args)
  defp dispatch("publish_post", args), do: publish_post(args)
  defp dispatch("unpublish_post", args), do: set_published(args, false)
  defp dispatch("delete_post", args), do: delete_post(args)
  defp dispatch("preview_post", args), do: preview_post(args)
  defp dispatch(other, _args), do: {:error, "unknown tool: #{other}"}

  @statuses ~w(all draft published)

  defp list_posts(args) do
    kind = Map.get(args, "kind")
    status = Map.get(args, "status", "all")

    if status in @statuses do
      posts =
        Content.list_posts()
        |> Enum.filter(&(is_nil(kind) or &1.kind == kind))
        |> Enum.filter(&status_matches?(&1, status))
        |> Enum.map(&post_summary/1)

      {:ok, posts}
    else
      {:error, "invalid status: #{inspect(status)}"}
    end
  end

  defp status_matches?(_post, "all"), do: true
  defp status_matches?(post, "draft"), do: !post.published
  defp status_matches?(post, "published"), do: post.published

  defp create_post(args) do
    case Map.get(args, "title") do
      title when is_binary(title) and title != "" ->
        attrs =
          %{
            "title" => title,
            "slug" => Map.get(args, "slug") || slugify(title),
            "body" => Map.get(args, "body", ""),
            "kind" => Map.get(args, "kind", "post"),
            "category" => Map.get(args, "category"),
            "tags" => Map.get(args, "tags"),
            "published" => Map.get(args, "published", false),
            "published_at" => Map.get(args, "published_at")
          }
          |> reject_nil_values()

        case Content.create_post(attrs) do
          {:ok, post} -> {:ok, post_detail(post)}
          {:error, changeset} -> {:error, changeset_errors(changeset)}
        end

      _ ->
        {:error, "title is required"}
    end
  end

  defp update_post(args) do
    with {:ok, post} <- find_post(args) do
      attrs =
        %{
          "title" => Map.get(args, "title"),
          "slug" => Map.get(args, "new_slug"),
          "body" => Map.get(args, "body"),
          "kind" => Map.get(args, "kind"),
          "category" => Map.get(args, "category"),
          "tags" => Map.get(args, "tags"),
          "published" => Map.get(args, "published"),
          "published_at" => Map.get(args, "published_at")
        }
        |> reject_nil_values()

      if map_size(attrs) == 0 do
        {:ok, post_detail(post)}
      else
        case Content.update_post(post, attrs) do
          {:ok, updated} -> {:ok, post_detail(updated)}
          {:error, changeset} -> {:error, changeset_errors(changeset)}
        end
      end
    end
  end

  defp publish_post(args) do
    with {:ok, post} <- find_post(args) do
      published_at = Map.get(args, "published_at") || post.published_at || Date.utc_today()

      case Content.update_post(post, %{"published" => true, "published_at" => published_at}) do
        {:ok, updated} -> {:ok, post_detail(updated)}
        {:error, changeset} -> {:error, changeset_errors(changeset)}
      end
    end
  end

  defp set_published(args, published) do
    with {:ok, post} <- find_post(args) do
      case Content.update_post(post, %{"published" => published}) do
        {:ok, updated} -> {:ok, post_detail(updated)}
        {:error, changeset} -> {:error, changeset_errors(changeset)}
      end
    end
  end

  defp delete_post(args) do
    with {:ok, post} <- find_post(args),
         {:ok, deleted} <- Content.delete_post(post) do
      {:ok, %{deleted: true, id: deleted.id, slug: deleted.slug}}
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset_errors(changeset)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp preview_post(args) do
    case Map.get(args, "body") do
      nil ->
        with {:ok, post} <- find_post(args) do
          {:ok, %{html: Content.render_body(post), excerpt: Content.excerpt(post)}}
        end

      body ->
        {:ok, %{html: Content.render_markdown(body), excerpt: Content.excerpt(body)}}
    end
  end

  defp find_post(args) do
    cond do
      id = Map.get(args, "id") -> find_by_id(id)
      slug = Map.get(args, "slug") -> find_by_slug(slug)
      true -> {:error, "id or slug is required"}
    end
  end

  defp find_by_id(id) when is_integer(id) do
    case Content.get_post(id) do
      nil -> {:error, "no post with id #{id}"}
      post -> {:ok, post}
    end
  end

  defp find_by_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> find_by_id(int)
      _ -> {:error, "id must be an integer"}
    end
  end

  defp find_by_id(_id), do: {:error, "id must be an integer"}

  defp find_by_slug(slug) when is_binary(slug) do
    case Content.get_by_slug(slug) do
      nil -> {:error, "no post with slug #{inspect(slug)}"}
      post -> {:ok, post}
    end
  end

  defp post_summary(%Post{} = post) do
    %{
      id: post.id,
      title: post.title,
      slug: post.slug,
      kind: post.kind,
      published: post.published,
      published_at: post.published_at && Date.to_iso8601(post.published_at),
      category: post.category,
      tags: post.tags,
      updated_at: post.updated_at && NaiveDateTime.to_iso8601(post.updated_at)
    }
  end

  defp post_detail(%Post{} = post) do
    Map.put(post_summary(post), :body, post.body)
  end

  defp reject_nil_values(map), do: Map.filter(map, fn {_k, v} -> not is_nil(v) end)

  # Mirrors BlogWeb.Admin.PostFormLive's client-side "From title" slugify,
  # for the same "spaces to hyphens" default when a caller doesn't pass one.
  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
  end

  defp changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
