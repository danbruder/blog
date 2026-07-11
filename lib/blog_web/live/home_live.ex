defmodule BlogWeb.HomeLive do
  use BlogWeb, :live_view

  alias Blog.Content

  @impl true
  def mount(_params, _session, socket) do
    posts = Content.list_published_posts()
    {:ok, assign(socket, posts: posts, page_title: "Dan Bruder | Software Engineering Manager")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl">
        <div class="text-center py-12 md:py-24">
          <h1 class="md:text-6xl text-sky-200">Hi, I'm Dan</h1>
          <span class="text-xl text-stone-200">
            I'm an engineering director working on <br /> making
            <a class="link" href="https://www.dronedeploy.com/">reality capture</a> easy
          </span>
        </div>

        <h4 class="text-lg md:text-xl text-gray-500">Latest Posts</h4>
        <div :for={post <- @posts} class="mb-6">
          <h2 class="text-xl md:text-3xl text-sky-200">
            <.link navigate={~p"/blog/#{post.slug}"}>{post.title}</.link>
          </h2>
          <label :if={post.published_at} class="text-gray-500">
            {Calendar.strftime(post.published_at, "%B %-d, %Y")}
          </label>
        </div>
      </div>
    </div>
    """
  end
end
