defmodule BlogWeb.WritingLive do
  use BlogWeb, :live_view

  alias Blog.Content

  @impl true
  def mount(_params, _session, socket) do
    posts = Content.list_published_posts()
    {:ok, assign(socket, posts: posts, page_title: "Writing | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero title="Writing" subtitle="Essays on software, management, and building things." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <h4 class="text-lg md:text-xl text-gray-500">Latest Posts</h4>
        <div :for={post <- @posts} class="mb-6">
          <h2 class="text-xl md:text-3xl text-[color:var(--accent-heading)]">
            <.link navigate={~p"/blog/#{post.slug}"}>{post.title}</.link>
          </h2>
          <time :if={post.published_at} datetime={Date.to_iso8601(post.published_at)} class="text-zinc-400">
            {Calendar.strftime(post.published_at, "%B %-d, %Y")}
          </time>
        </div>

        <p class="mt-8 text-sm text-zinc-400">
          Looking for smaller learnings and TILs?
          <.link class="link" navigate={~p"/notes"}>Check out the notes</.link>.
        </p>
      </div>
    </div>
    """
  end
end
