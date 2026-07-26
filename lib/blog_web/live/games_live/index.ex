defmodule BlogWeb.GamesLive.Index do
  use BlogWeb, :live_view

  @games [
    %{
      name: "SNAKE",
      kind: "Multiplayer",
      href: "/games/snake",
      slot: "snake board capture",
      fill:
        "repeating-linear-gradient(90deg,var(--color-paper-2) 0 10px,var(--color-paper-3) 10px 20px)",
      desc:
        "A single global board. Everyone who opens the page is a snake in the same game — no lobby, no rounds, just whatever is happening right now."
    },
    %{
      name: "SAND",
      kind: "Sandbox",
      href: "/games/sand",
      slot: "falling sand capture",
      fill:
        "repeating-linear-gradient(45deg,var(--color-paper-2) 0 10px,var(--color-paper-3) 10px 20px)",
      desc:
        "A shared falling-sand sandbox. Paint sand, water and fire, and watch what the other people on the page are doing to it."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, games: @games, page_title: "Games | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero
      eyebrow="Games"
      title="Little things to play with."
      subtitle="Shared, always-on, no account. Everyone who opens the page lands in the same world."
    />

    <.page_body>
      <div class="grid grid-cols-1 gap-7 sm:grid-cols-[repeat(auto-fit,minmax(280px,1fr))]">
        <div :for={game <- @games} class="flex flex-col border border-ink">
          <div
            class="flex aspect-[4/3] items-end border-b border-ink p-3.5"
            style={"background: #{game.fill};"}
          >
            <span class="bg-paper px-1.5 py-0.5 font-mono text-[10.5px] text-ink-3">
              {game.slot}
            </span>
          </div>
          <div class="flex flex-1 flex-col gap-2.5 p-6">
            <div class="flex items-baseline justify-between">
              <h2 class="font-display text-[26px] font-bold tracking-[-0.035em] text-ink">
                {game.name}
              </h2>
              <span class="text-[10.5px] font-semibold uppercase tracking-[0.12em] text-ink-3">
                {game.kind}
              </span>
            </div>
            <p class="flex-1 text-[14.5px] leading-[1.5] text-ink-2">{game.desc}</p>
            <.link
              navigate={game.href}
              class="mt-1.5 self-start border border-ink bg-ink px-4 py-[9px] text-[13px] font-semibold uppercase tracking-[0.04em] text-paper !shadow-none transition-colors hover:!bg-lime hover:!text-on-lime"
            >
              Play →
            </.link>
          </div>
        </div>
      </div>
    </.page_body>
    """
  end
end
