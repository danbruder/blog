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
           meta_description: Content.excerpt(post),
           reading_time: reading_time(post),
           body_html: Content.render_body(post)
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="border-b border-rule px-6 py-6 sm:px-10 lg:px-14">
      <.link
        navigate={back_href(@post)}
        class="label !text-ink-2 !shadow-none hover:!bg-lime hover:!text-on-lime"
      >
        ← All {back_label(@post)}
      </.link>
    </div>

    <article class="max-w-[42em] px-6 pt-14 sm:px-10 lg:px-14">
      <div class="mb-5 flex flex-wrap items-center gap-x-3.5 gap-y-2">
        <span :if={@post.published_at} class="label">
          {Calendar.strftime(@post.published_at, "%b %-d %Y")}
        </span>
        <span class="text-ink-3">·</span>
        <span class="label">{@reading_time} min</span>
        <span :if={@post.category} class="text-ink-3">·</span>
        <span :if={@post.category} class="label !text-ink">{@post.category}</span>
      </div>

      <h1 class="font-display text-[clamp(34px,5vw,54px)] font-bold leading-[0.96] tracking-[-0.045em] text-ink">
        {@post.title}
      </h1>

      <div id="post-body" phx-hook="Highlight" phx-update="ignore" class="markdown-content">
        {Phoenix.HTML.raw(@body_html)}
      </div>

      <form
        :if={@post.kind == "post"}
        action="https://buttondown.email/api/emails/embed-subscribe/danbruder"
        method="post"
        target="popupwindow"
        onsubmit="window.open('https://buttondown.email/danbruder', 'popupwindow')"
        class="embeddable-buttondown-form mt-20 p-6"
      >
        <label for="bd-email" class="label mb-3 block">Newsletter — one letter a month</label>
        <div class="flex flex-wrap gap-2">
          <input
            type="email"
            class="min-w-0 flex-1 border border-ink bg-paper px-3 py-[10px] text-[14.5px] text-ink outline-none focus:shadow-[0_0_0_3px_var(--color-lime)]"
            placeholder="you@example.com"
            name="email"
            id="bd-email"
          />
          <input
            type="submit"
            class="cursor-pointer border border-ink bg-ink px-[18px] py-[10px] text-[13px] font-semibold tracking-[0.04em] text-paper transition-colors hover:bg-lime hover:text-on-lime"
            value="Subscribe"
          />
        </div>
      </form>

      <div :if={@post.kind == "post"} class="mt-12 border-t border-ink pt-[18px]">
        <p class="label mb-2">Made it this far?</p>
        <.link
          navigate={~p"/games/snake"}
          class="font-display text-[22px] font-medium leading-[1.2] tracking-[-0.028em] !shadow-none hover:!bg-lime hover:!text-on-lime"
        >
          Have a go at the game of snake →
        </.link>
      </div>
    </article>
    """
  end

  defp back_href(%{kind: "note"}), do: ~p"/notes"
  defp back_href(_), do: ~p"/writing"

  defp back_label(%{kind: "note"}), do: "notes"
  defp back_label(_), do: "writing"

  defp reading_time(%{body: body}) when is_binary(body) do
    words = body |> String.split(~r/\s+/, trim: true) |> length()
    max(1, round(words / 200))
  end

  defp reading_time(_), do: 1
end
