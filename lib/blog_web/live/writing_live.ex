defmodule BlogWeb.WritingLive do
  use BlogWeb, :live_view

  alias Blog.Content

  @impl true
  def mount(_params, _session, socket) do
    groups =
      Content.list_published_posts()
      |> Enum.group_by(fn post -> year_of(post) end)
      |> Enum.sort_by(fn {year, _} -> year end, :desc)

    {:ok, assign(socket, groups: groups, page_title: "Writing | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero
      eyebrow="Writing"
      title="Essays on software, management, and building things."
      subtitle="Long-form, infrequent, written after the fact — mostly about running engineering teams without pretending the work is tidy."
    />

    <.page_body class="pt-0">
      <div
        :for={{year, posts} <- @groups}
        class="grid grid-cols-[64px_minmax(0,1fr)] gap-6 border-b border-rule pt-8 sm:grid-cols-[88px_minmax(0,1fr)]"
      >
        <div class="pt-1 font-display text-[15px] font-bold tracking-[0.02em] text-ink-3">
          {year}
        </div>
        <div>
          <.link
            :for={post <- posts}
            navigate={~p"/blog/#{post.slug}"}
            class="group grid grid-cols-[minmax(0,1fr)_72px] items-baseline gap-5 !shadow-none hover:!bg-transparent pb-6"
          >
            <div>
              <div class="font-display text-[22px] font-medium leading-[1.2] tracking-[-0.028em] text-ink transition-colors group-hover:bg-lime group-hover:text-on-lime sm:text-[24px]">
                {post.title}
              </div>
              <div :if={blurb(post)} class="mt-[7px] max-w-[40em] text-[13.5px] text-ink-2">
                {blurb(post)}
              </div>
            </div>
            <div class="text-right text-[11.5px] tracking-[0.04em] text-ink-3">
              {day_of(post)}
            </div>
          </.link>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2 pt-7 text-[14px] text-ink-2">
        <span>Smaller learnings and TILs live in</span>
        <.link
          navigate={~p"/notes"}
          class="font-semibold !shadow-[inset_0_-1px_0_var(--color-ink)] hover:!bg-lime hover:!text-on-lime"
        >
          the notes
        </.link>
      </div>
    </.page_body>
    """
  end

  defp year_of(%{published_at: %Date{year: year}}), do: year
  defp year_of(_), do: 0

  defp day_of(%{published_at: %Date{} = date}), do: Calendar.strftime(date, "%b %-d")
  defp day_of(_), do: ""

  defp blurb(post) do
    case Content.excerpt(post, 120) do
      "" -> nil
      text -> text
    end
  end
end
