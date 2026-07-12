defmodule BlogWeb.ProjectLive.Index do
  use BlogWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Projects | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero title="Projects" subtitle="Things I'm building." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <p class="text-zinc-400">Coming soon.</p>
      </div>
    </div>
    """
  end
end
