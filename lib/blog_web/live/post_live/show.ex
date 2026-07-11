defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Content

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Content.get_published_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That page doesn't exist.")
         |> redirect(to: ~p"/")}

      post ->
        {:ok,
         assign(socket,
           post: post,
           page_title: post.title,
           body_html: Content.render_body(post)
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl">
        <h1 class="md:text-5xl text-sky-200">{@post.title}</h1>
        <span :if={@post.published_at} class="text-gray-500 font-bold flex items-center space-x-3">
          <div>{Calendar.strftime(@post.published_at, "%B %-d, %Y")}</div>
        </span>

        <div id="post-body" phx-hook="Highlight" phx-update="ignore" class="markdown-content">
          {Phoenix.HTML.raw(@body_html)}
        </div>

        <form
          :if={@post.kind == "post"}
          action="https://buttondown.email/api/emails/embed-subscribe/danbruder"
          method="post"
          target="popupwindow"
          onsubmit="window.open('https://buttondown.email/danbruder', 'popupwindow')"
          class="embeddable-buttondown-form bg-zinc-800 p-4 mt-24"
        >
          <label for="bd-email" class="block pb-2">Newsletter signup:</label>
          <input
            type="email"
            class="bg-zinc-700 text-zinc-100 rounded my-2"
            placeholder="email"
            name="email"
            id="bd-email"
          />
          <input
            type="submit"
            class="bg-sky-900 text-sky-400 p-2 rounded border border-sky-900 bg-opacity-50"
            value="Subscribe"
          />
        </form>

        <h3 :if={@post.kind == "post"} class="mt-12">
          Made it this far? Have a go at the game of
          <a class="underline" href={~p"/snake"}>snake</a>
        </h3>
      </div>
    </div>
    """
  end
end
