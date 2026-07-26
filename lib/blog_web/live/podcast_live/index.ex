defmodule BlogWeb.PodcastLive.Index do
  use BlogWeb, :live_view

  @appearances [
    %{
      show: "Software Unscripted",
      year: "2024",
      title: "Elm + Rust at StructionSite",
      blurb:
        "What it's actually like to run production construction-tech tooling on two typed functional languages.",
      url: "https://open.spotify.com/episode/6cnAHvdCXedoHxG4w9pWOV"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, appearances: @appearances, page_title: "Podcasts | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero eyebrow="Podcasts" title="Shows I've been a guest on." />

    <.page_body>
      <div
        :for={ep <- @appearances}
        class="grid grid-cols-1 border border-ink sm:grid-cols-[200px_minmax(0,1fr)]"
      >
        <div class="flex items-end border-b border-ink bg-[repeating-linear-gradient(135deg,var(--color-paper-2)_0_8px,var(--color-paper-3)_8px_16px)] p-3.5 sm:border-b-0 sm:border-r">
          <span class="bg-paper px-1.5 py-0.5 font-mono text-[10.5px] text-ink-3">show artwork</span>
        </div>
        <div class="p-8">
          <p class="label mb-3.5">{ep.show} · {ep.year}</p>
          <h2 class="font-display text-[clamp(24px,3vw,32px)] font-semibold leading-[1.02] tracking-[-0.035em] text-ink">
            {ep.title}
          </h2>
          <p class="mt-3.5 max-w-[34em] text-[16px] leading-[1.6] text-ink-2">{ep.blurb}</p>
          <a
            href={ep.url}
            class="mt-6 inline-block border border-ink bg-ink px-[18px] py-[10px] text-[13px] font-semibold uppercase tracking-[0.04em] text-paper !shadow-none transition-colors hover:!bg-lime hover:!text-on-lime"
          >
            Listen →
          </a>
        </div>
      </div>

      <p class="mt-6 max-w-[34em] text-[14px] text-ink-3">
        Happy to talk about engineering management, remote teams, or shipping Elixir and Rust in anger. <a
          href="https://github.com/danbruder"
          class="!text-ink-2"
        >Get in touch</a>.
      </p>
    </.page_body>
    """
  end
end
