defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Analytics
  alias Blog.Content

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    case Content.get_published_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That page doesn't exist.")
         |> redirect(to: ~p"/")}

      post ->
        post_path = post_path(post)

        {:ok,
         assign(socket,
           post: post,
           page_title: post.title,
           meta_description: Content.excerpt(post),
           reading_time: reading_time(post),
           body_html: Content.render_body(post),
           post_path: post_path,
           stats: post_stats(post_path),
           kudos_given?: post_path in (session["kudos_paths"] || [])
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

      <div class="mt-10 flex flex-wrap items-center justify-between gap-6 border-t border-rule pt-6">
        <div class="flex flex-wrap gap-x-4 gap-y-1 text-[13px] text-ink-3">
          <span :if={@stats.views_all_time > 0}>
            {format_count(@stats.views_all_time)} views all time
          </span>
          <span :if={@stats.views_last_week > 0}>
            {format_count(@stats.views_last_week)} in the last week
          </span>
        </div>

        <div
          id="kudos"
          phx-hook="Kudos"
          phx-update="ignore"
          data-path={@post_path}
          data-given={to_string(@kudos_given?)}
          data-kudos={@stats.kudos}
          class="kudos-widget flex items-center gap-2.5"
        >
          <button
            type="button"
            data-kudos-button
            class="kudos-button relative flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden border border-ink text-ink transition-colors"
            aria-label="Give kudos"
            title="Hold for 3 seconds to give kudos"
          >
            <span
              data-kudos-fill
              class="kudos-fill pointer-events-none absolute inset-x-0 bottom-0 h-0 bg-lime"
            ></span>
            <svg
              viewBox="0 0 24 24"
              class="kudos-thumb pointer-events-none relative h-4 w-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M7 22V10M2 13v7a2 2 0 0 0 2 2h12.6a2 2 0 0 0 1.98-1.7l1.2-8A2 2 0 0 0 17.8 10H13V5a2 2 0 0 0-2-2L7 10" />
            </svg>
          </button>
          <span class="text-[13px] text-ink-2">
            <span data-kudos-count>{@stats.kudos}</span>
            kudos &middot;
            <span data-kudos-label>{if @kudos_given?, do: "Thanks!", else: "hold to give kudos"}</span>
          </span>
        </div>
      </div>

      <form
        :if={@post.kind == "post"}
        action="https://buttondown.email/api/emails/embed-subscribe/danbruder"
        method="post"
        target="popupwindow"
        onsubmit="window.open('https://buttondown.email/danbruder', 'popupwindow')"
        class="embeddable-buttondown-form mt-20 p-6"
      >
        <label for="bd-email" class="label mb-3 block">Newsletter: one letter a month</label>
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
          navigate={~p"/sea"}
          class="font-display text-[22px] font-medium leading-[1.2] tracking-[-0.028em] !shadow-none hover:!bg-lime hover:!text-on-lime"
        >
          Explore this site in 3D →
        </.link>
      </div>
    </article>
    """
  end

  defp back_href(%{kind: "note"}), do: ~p"/notes"
  defp back_href(_), do: ~p"/writing"

  defp back_label(%{kind: "note"}), do: "notes"
  defp back_label(_), do: "writing"

  # The path this post is served at -- matches the routes in
  # BlogWeb.Router, and thus the `path` that BlogWeb.AnalyticsTracker
  # records page views under and what BlogWeb.KudosController keys kudos to.
  defp post_path(%{kind: "note", slug: slug}), do: ~p"/notes/#{slug}"
  defp post_path(%{slug: slug}), do: ~p"/blog/#{slug}"

  defp post_stats(path) do
    case Analytics.post_stats(path) do
      {:ok, stats} -> stats
      {:error, _reason} -> %{views_all_time: 0, views_last_week: 0, kudos: 0}
    end
  end

  # "12345" -> "12,345"; used for the view counts in the post footer.
  defp format_count(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp reading_time(%{body: body}) when is_binary(body) do
    words = body |> String.split(~r/\s+/, trim: true) |> length()
    max(1, round(words / 200))
  end

  defp reading_time(_), do: 1
end
