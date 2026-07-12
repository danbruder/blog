defmodule BlogWeb.Admin.PostIndexLive do
  use BlogWeb, :live_view

  alias Blog.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Admin", posts: Content.list_posts())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    {:ok, _} = Content.delete_post(post)

    {:noreply, assign(socket, posts: Content.list_posts())}
  end

  defp public_path(%{kind: "note", slug: slug}), do: "/notes/#{slug}"
  defp public_path(%{slug: slug}), do: "/blog/#{slug}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-3xl">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-3xl text-sky-200">Posts</h1>
          <div class="flex items-center gap-3">
            <.link navigate={~p"/admin/viewers"} class="text-sm text-zinc-400 underline">
              Viewers
            </.link>
            <.link navigate={~p"/admin/posts/new"}>
              <.button>New post</.button>
            </.link>
            <.link href={~p"/admin/logout"} method="delete" class="text-sm text-zinc-400 underline">
              Log out
            </.link>
          </div>
        </div>

        <div class="divide-y divide-zinc-800">
          <div :for={post <- @posts} class="py-4 flex items-center justify-between gap-4">
            <div>
              <div class="flex items-center gap-2">
                <span class={[
                  "text-xs px-2 py-0.5 rounded border",
                  post.published && "border-sky-800 text-sky-300",
                  !post.published && "border-zinc-700 text-zinc-500"
                ]}>
                  {if post.published, do: "published", else: "draft"}
                </span>
                <span class="text-xs px-2 py-0.5 rounded border border-zinc-700 text-zinc-500">
                  {post.kind}
                </span>
                <span class="text-lg text-sky-100">{post.title}</span>
              </div>
              <div class="text-sm text-zinc-500">
                {public_path(post)}
                <span :if={post.published_at}>
                  &middot; {Calendar.strftime(post.published_at, "%B %-d, %Y")}
                </span>
              </div>
            </div>
            <div class="flex items-center gap-3 shrink-0">
              <.link navigate={~p"/admin/posts/#{post.id}/edit"} class="text-sky-300 underline">
                Edit
              </.link>
              <.link
                phx-click="delete"
                phx-value-id={post.id}
                data-confirm={"Delete \"#{post.title}\"?"}
                class="text-orange-300 underline"
              >
                Delete
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
