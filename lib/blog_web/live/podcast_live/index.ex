defmodule BlogWeb.PodcastLive.Index do
  use BlogWeb, :live_view

  @appearances [
    %{
      show: "Software Unscripted",
      title: "Elm + Rust at StructionSite",
      blurb:
        "I shared our experience using Elm and Rust to build construction-tech tooling at StructionSite.",
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
    <.page_hero title="Podcasts" subtitle="Shows I've been a guest on." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <h4 class="text-lg text-gray-500 mb-4">Appearances</h4>
        <div :for={ep <- @appearances} class="browser bg-zinc-800 p-6 mb-6">
          <p class="font-fancy text-sm uppercase tracking-wide text-zinc-400">{ep.show}</p>
          <h2 class="text-xl text-[color:var(--accent-heading)] mt-1">{ep.title}</h2>
          <p class="text-sm text-zinc-400 mt-2">{ep.blurb}</p>
          <a class="link inline-block mt-3" href={ep.url}>Listen →</a>
        </div>
      </div>
    </div>
    """
  end
end
