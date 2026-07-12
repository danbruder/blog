defmodule BlogWeb.GamesLive.Index do
  use BlogWeb, :live_view

  @games [
    %{
      name: "Snake",
      href: "/games/snake",
      blurb: "A single global multiplayer snake — everyone shares one board.",
      emoji: "🐍"
    },
    %{
      name: "Sand",
      href: "/games/sand",
      blurb: "A shared falling-sand sandbox — paint sand, water, fire, and watch it flow.",
      emoji: "🏖️"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, games: @games, page_title: "Games | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero title="Games" subtitle="Little things to play with." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <.link
            :for={game <- @games}
            navigate={game.href}
            class="browser bg-zinc-800 p-6 no-underline block"
          >
            <div class="text-3xl mb-2">{game.emoji}</div>
            <h2 class="text-xl text-[color:var(--accent-heading)]">{game.name}</h2>
            <p class="text-sm text-zinc-400 mt-1">{game.blurb}</p>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
