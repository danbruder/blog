defmodule BlogWeb.ProjectLive.Index do
  use BlogWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Projects | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero
      eyebrow="Projects"
      title="Things I'm building."
      subtitle="Mostly small, mostly Elixir, mostly unfinished. Each one gets a line here when it does something useful for someone other than me."
    />

    <.page_body>
      <div class="flex flex-col items-start gap-4 border border-dashed border-rule p-10 sm:p-11">
        <span class="mark text-[11px] font-semibold uppercase tracking-[0.14em]">In progress</span>
        <div class="max-w-[16em] font-display text-[clamp(22px,3vw,28px)] font-semibold leading-[1.05] tracking-[-0.035em] text-ink">
          Nothing here yet. Check out the games page in the mean time.
        </div>
        <div class="mt-1 flex flex-wrap gap-2.5">
          <.link
            navigate={~p"/games"}
            class="border border-ink px-[18px] py-[10px] text-[13px] font-semibold uppercase tracking-[0.04em] text-ink !shadow-none transition-colors hover:!bg-lime hover:!text-on-lime"
          >
            See the games
          </.link>
          <a
            href="https://github.com/danbruder"
            class="border border-rule px-[18px] py-[10px] text-[13px] font-semibold uppercase tracking-[0.04em] !text-ink-2 !shadow-none transition-colors hover:!bg-lime hover:!text-on-lime"
          >
            GitHub
          </a>
        </div>
      </div>
    </.page_body>
    """
  end
end
