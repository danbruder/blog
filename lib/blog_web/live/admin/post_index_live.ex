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
    <.page_body>
      <div class="mx-auto max-w-3xl">
        <div class="mb-8 flex items-center justify-between gap-4">
          <h1 class="font-display text-[28px] font-bold tracking-[-0.03em] text-ink">Posts</h1>
          <div class="flex items-center gap-4">
            <.link
              navigate={~p"/admin/viewers"}
              class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
            >
              Viewers
            </.link>
            <.link
              navigate={~p"/admin/analytics"}
              class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
            >
              Analytics
            </.link>
            <.link navigate={~p"/admin/posts/new"}>
              <.button>New post</.button>
            </.link>
            <.link
              href={~p"/admin/logout"}
              method="delete"
              class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
            >
              Log out
            </.link>
          </div>
        </div>

        <div class="divide-y divide-rule">
          <div :for={post <- @posts} class="flex items-center justify-between gap-4 py-4">
            <div>
              <div class="flex items-center gap-2">
                <span class={[
                  "border px-2 py-0.5 text-[11px] uppercase tracking-[0.04em]",
                  post.published && "border-ink text-ink",
                  !post.published && "border-rule text-ink-3"
                ]}>
                  {if post.published, do: "published", else: "draft"}
                </span>
                <span class="border border-rule px-2 py-0.5 text-[11px] uppercase tracking-[0.04em] text-ink-3">
                  {post.kind}
                </span>
                <span class="text-[17px] text-ink">{post.title}</span>
              </div>
              <div class="mt-1 text-[13px] text-ink-3">
                {public_path(post)}
                <span :if={post.published_at}>
                  &middot; {Calendar.strftime(post.published_at, "%B %-d, %Y")}
                </span>
              </div>
            </div>
            <div class="flex shrink-0 items-center gap-3">
              <.link
                navigate={~p"/admin/posts/#{post.id}/edit"}
                class="text-[13px] text-ink !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!bg-lime hover:!text-on-lime"
              >
                Edit
              </.link>
              <.link
                phx-click="delete"
                phx-value-id={post.id}
                data-confirm={"Delete \"#{post.title}\"?"}
                class="text-[13px] text-signal !shadow-[inset_0_-1px_0_var(--color-rule)]"
              >
                Delete
              </.link>
            </div>
          </div>
        </div>
      </div>
    </.page_body>
    """
  end
end
