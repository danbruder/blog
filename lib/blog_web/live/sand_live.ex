defmodule BlogWeb.SandLive do
  use BlogWeb, :live_view

  alias Blog.SandGame

  @elements [
    {"Sand", 1},
    {"Water", 2},
    {"Stone", 3},
    {"Wood", 4},
    {"Fire", 5},
    {"Erase", 0}
  ]

  @impl true
  def mount(_params, _session, socket) do
    %{width: w, height: h} = SandGame.dims()

    socket =
      socket
      |> assign(
        page_title: "Sand",
        game_name: "Sand",
        width: w,
        height: h,
        selected: 1,
        elements: @elements
      )

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blog.PubSub, SandGame.topic())
      {_count, grid} = SandGame.join(self())
      socket = push_event(socket, "grid", %{grid: Base.encode64(grid)})
      {:ok, socket, layout: {BlogWeb.Layouts, :game}}
    else
      {:ok, socket, layout: {BlogWeb.Layouts, :game}}
    end
  end

  @impl true
  def handle_event("select", %{"code" => code}, socket) do
    {:noreply, assign(socket, selected: String.to_integer(code))}
  end

  def handle_event("paint", %{"cells" => cells, "element" => code}, socket) do
    SandGame.paint(cells, code)
    {:noreply, socket}
  end

  def handle_event("clear", _params, socket) do
    SandGame.clear()
    {:noreply, socket}
  end

  @impl true
  def handle_info({:sand_grid, grid_b64}, socket) do
    {:noreply, push_event(socket, "grid", %{grid: grid_b64})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-4 gap-3">
      <div class="shrink-0 flex flex-wrap items-center gap-2">
        <button
          :for={{label, code} <- @elements}
          type="button"
          phx-click="select"
          phx-value-code={code}
          class={[
            "!rounded-lg !border px-3 py-1.5 text-sm !shadow-none",
            @selected == code && "!border-sky-300 text-sky-200 bg-zinc-700",
            @selected != code && "!border-zinc-600 text-zinc-300 bg-zinc-800"
          ]}
        >
          {label}
        </button>
        <button
          type="button"
          phx-click="clear"
          class="!rounded-lg !border !border-zinc-600 !shadow-none px-3 py-1.5 text-sm text-zinc-300 bg-zinc-800 ml-auto"
        >
          Clear
        </button>
      </div>

      <div class="flex-1 min-h-0 flex items-center justify-center">
        <canvas
          id="sand-canvas"
          phx-hook="SandCanvas"
          phx-update="ignore"
          data-w={@width}
          data-h={@height}
          data-selected={@selected}
          class="border border-zinc-700 rounded max-h-full max-w-full"
          style="image-rendering: pixelated; aspect-ratio: 120 / 80; width: auto; height: 100%;"
        ></canvas>
      </div>
    </div>
    """
  end
end
