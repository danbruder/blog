defmodule BlogWeb.SnakeLive do
  @moduledoc """
  A view onto the single global game run by `Blog.SnakeGame`. Every visitor
  gets their own snake on one shared board; the player list shows who's active.
  """
  use BlogWeb, :live_view

  alias Blog.SnakeGame

  @cell 18

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blog.PubSub, SnakeGame.topic())
      {id, state} = SnakeGame.join(self())

      {:ok,
       assign(socket,
         player_id: id,
         game: state,
         page_title: "Snake",
         connected: true,
         editing_name: false
       )}
    else
      dims = SnakeGame.dims()

      {:ok,
       assign(socket,
         player_id: nil,
         game: %{cols: dims.cols, rows: dims.rows, players: [], foods: []},
         page_title: "Snake",
         connected: false,
         editing_name: false
       )}
    end
  end

  @impl true
  def handle_event("key", _params, %{assigns: %{editing_name: true}} = socket) do
    # Don't steer the snake while the player is typing a new name.
    {:noreply, socket}
  end

  def handle_event("key", %{"key" => key}, socket) do
    case dir_for_key(key) do
      nil -> {:noreply, socket}
      dir -> {:noreply, send_dir(socket, dir)}
    end
  end

  def handle_event("dir", %{"dir" => dir}, socket) do
    {:noreply, send_dir(socket, String.to_existing_atom(dir))}
  end

  def handle_event("edit_name", _params, socket) do
    {:noreply, assign(socket, editing_name: true)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_name: false)}
  end

  def handle_event("rename", %{"name" => name}, socket) do
    if socket.assigns.player_id, do: SnakeGame.rename(socket.assigns.player_id, name)
    {:noreply, assign(socket, editing_name: false)}
  end

  @impl true
  def handle_info({:snake_state, state}, socket) do
    {:noreply, assign(socket, game: state)}
  end

  defp send_dir(socket, dir) do
    if socket.assigns.player_id, do: SnakeGame.set_direction(socket.assigns.player_id, dir)
    socket
  end

  @fruits ~w(🍎 🍊 🍋 🍇 🍓 🍉 🍒 🍑 🍍 🥝 🍌 🫐)
  # Deterministic per-cell so a given pellet keeps the same fruit while it sits
  # on the board (no flicker on re-render).
  defp fruit(x, y), do: Enum.at(@fruits, rem(x * 31 + y * 7, length(@fruits)))

  defp dir_for_key(key) when key in ["ArrowUp", "w", "W"], do: :up
  defp dir_for_key(key) when key in ["ArrowDown", "s", "S"], do: :down
  defp dir_for_key(key) when key in ["ArrowLeft", "a", "A"], do: :left
  defp dir_for_key(key) when key in ["ArrowRight", "d", "D"], do: :right
  defp dir_for_key(_), do: nil

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :cell, @cell)

    ~H"""
    <.page_hero
      title="Snake"
      eyebrow="Games"
      subtitle="A single global game — everyone here shares the board. Arrow keys or WASD to steer; crash and you respawn."
    />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10" phx-window-keydown="key">
      <div class="mx-auto max-w-5xl">

        <div class="flex flex-col md:flex-row gap-6 items-start">
          <div class="flex-1 min-w-0">
            <svg
              viewBox={"0 0 #{@game.cols * @cell} #{@game.rows * @cell}"}
              class="snake bg-zinc-800 w-full h-auto"
              preserveAspectRatio="xMidYMid meet"
            >
              <text
                :for={{x, y} <- @game.foods}
                x={x * @cell + @cell / 2}
                y={y * @cell + @cell / 2}
                font-size={@cell}
                text-anchor="middle"
                dominant-baseline="central"
              >{fruit(x, y)}</text>

              <%= for player <- @game.players do %>
                <rect
                  :for={{{x, y}, idx} <- Enum.with_index(player.body)}
                  x={x * @cell + 1}
                  y={y * @cell + 1}
                  width={@cell - 2}
                  height={@cell - 2}
                  rx="3"
                  fill={player.color}
                  fill-opacity={if idx == 0, do: "1", else: "0.75"}
                  stroke={if player.id == @player_id, do: "#fafafa", else: "none"}
                  stroke-width={if player.id == @player_id and idx == 0, do: "2", else: "0"}
                />
              <% end %>
            </svg>

            <div class="flex justify-center items-center space-x-4 mt-6 md:hidden">
              <button phx-click="dir" phx-value-dir="left" class="bg-gray-700 uppercase px-3 py-2">←</button>
              <button phx-click="dir" phx-value-dir="up" class="bg-gray-700 uppercase px-3 py-2">↑</button>
              <button phx-click="dir" phx-value-dir="down" class="bg-gray-700 uppercase px-3 py-2">↓</button>
              <button phx-click="dir" phx-value-dir="right" class="bg-gray-700 uppercase px-3 py-2">→</button>
            </div>
          </div>

          <div class="w-full md:w-56 shrink-0">
            <h4 class="text-lg text-gray-400 mb-3">
              Players ({length(@game.players)})
            </h4>
            <ul class="space-y-2">
              <li
                :for={player <- @game.players}
                class={"flex items-center justify-between px-3 py-2 rounded-lg " <> if(player.id == @player_id, do: "bg-zinc-700", else: "bg-zinc-800")}
              >
                <span class="flex items-center space-x-2 min-w-0">
                  <span class="w-3 h-3 rounded-full shrink-0" style={"background: #{player.color}"}></span>
                  <%= cond do %>
                    <% player.id == @player_id and @editing_name -> %>
                      <form phx-submit="rename" class="min-w-0">
                        <input
                          type="text"
                          name="name"
                          value={player.name}
                          maxlength="20"
                          autofocus
                          phx-blur="cancel_edit"
                          phx-mounted={JS.focus()}
                          class="bg-zinc-900 text-zinc-100 rounded px-2 py-0.5 text-sm w-32"
                        />
                      </form>
                    <% player.id == @player_id -> %>
                      <span
                        id="my-name"
                        phx-hook="DblClickEdit"
                        title="Double-click to rename"
                        class="truncate text-zinc-200 cursor-pointer border-b border-dashed border-zinc-600"
                      >
                        {player.name}<span class="text-gray-500"> (you)</span>
                      </span>
                    <% true -> %>
                      <span class="truncate text-zinc-200">{player.name}</span>
                  <% end %>
                </span>
                <span class="text-zinc-400 font-fancy">{player.score}</span>
              </li>
              <li :if={@game.players == []} class="text-gray-500 px-3">
                <span :if={@connected}>Waiting for players…</span>
                <span :if={!@connected}>Connecting…</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
