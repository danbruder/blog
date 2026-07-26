defmodule Blog.SnakeGame do
  @moduledoc """
  A single, global, multiplayer game of snake shared by everyone currently
  viewing `/games/snake`.

  This is one authoritative GenServer (registered by module name) that owns the
  whole board. Each connected `BlogWeb.SnakeLive` process `join/1`s to get its
  own snake; the game monitors that pid so closing the tab removes the player.
  On every tick the game advances all snakes and broadcasts the full state over
  `Blog.PubSub` on the topic `"snake"`.
  """
  use GenServer

  @topic "snake"
  @cols 40
  @rows 28
  @tick_ms 140
  @start_len 3
  @food_count 5

  @colors ~w(#f87171 #facc15 #4ade80 #38bdf8 #a78bfa #fb923c #f472b6 #2dd4bf #a3e635 #e879f9)
  @adjectives ~w(swift sneaky brave sleepy witty jazzy mellow zippy plucky cosmic)
  @animals ~w(otter fox lynx heron gecko koala raven moth ferret tapir)

  # Public API ---------------------------------------------------------------

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def topic, do: @topic
  def dims, do: %{cols: @cols, rows: @rows}

  @doc "Register the calling process as a player. Returns {player_id, state}."
  def join(pid), do: GenServer.call(__MODULE__, {:join, pid})

  @doc "Queue a direction change for a player (:up/:down/:left/:right)."
  def set_direction(player_id, dir), do: GenServer.cast(__MODULE__, {:dir, player_id, dir})

  @doc "Rename a player. Blank/oversized names are cleaned up server-side."
  def rename(player_id, name), do: GenServer.cast(__MODULE__, {:rename, player_id, name})

  def state, do: GenServer.call(__MODULE__, :state)

  # GenServer ----------------------------------------------------------------

  @impl true
  def init(:ok) do
    :timer.send_interval(@tick_ms, :tick)
    {:ok, %{players: %{}, foods: spawn_foods([], %{}), next_id: 1}}
  end

  @impl true
  def handle_call({:join, pid}, _from, state) do
    ref = Process.monitor(pid)
    id = "p#{state.next_id}"
    used_colors = Enum.map(state.players, fn {_, p} -> p.color end)
    color = Enum.find(Enum.shuffle(@colors), hd(@colors), &(&1 not in used_colors))

    player = %{
      id: id,
      pid: pid,
      ref: ref,
      name: random_name(),
      color: color,
      score: 0,
      alive: true,
      dir: :right,
      pending: :right,
      body: nil
    }

    player = %{player | body: spawn_body(occupied(state.players), player.dir)}
    players = Map.put(state.players, id, player)
    new_state = %{state | players: players, next_id: state.next_id + 1}
    broadcast(new_state)
    {:reply, {id, public(new_state)}, new_state}
  end

  def handle_call(:state, _from, state), do: {:reply, public(state), state}

  @impl true
  def handle_cast({:dir, id, dir}, state) when dir in [:up, :down, :left, :right] do
    players =
      case state.players do
        %{^id => p} ->
          # Ignore a 180° reversal against the direction actually being travelled.
          if opposite?(dir, p.dir),
            do: state.players,
            else: %{state.players | id => %{p | pending: dir}}

        _ ->
          state.players
      end

    {:noreply, %{state | players: players}}
  end

  def handle_cast({:dir, _id, _dir}, state), do: {:noreply, state}

  def handle_cast({:rename, id, name}, state) do
    players =
      case state.players do
        %{^id => p} -> %{state.players | id => %{p | name: clean_name(name, p.name)}}
        _ -> state.players
      end

    new_state = %{state | players: players}
    broadcast(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:tick, state) do
    state = if map_size(state.players) == 0, do: state, else: step(state)
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    players =
      state.players
      |> Enum.reject(fn {_id, p} -> p.ref == ref end)
      |> Map.new()

    new_state = %{state | players: players}
    broadcast(new_state)
    {:noreply, new_state}
  end

  # Game step ----------------------------------------------------------------

  defp step(state) do
    # Apply queued direction changes.
    players =
      Map.new(state.players, fn {id, p} -> {id, %{p | dir: p.pending}} end)

    # Everyone occupies their current cells this tick.
    all_bodies = for {_id, p} <- players, cell <- p.body, into: MapSet.new(), do: cell

    # Intended new heads.
    heads = Map.new(players, fn {id, p} -> {id, step_head(hd(p.body), p.dir)} end)

    eating = Map.new(players, fn {id, _p} -> {id, heads[id] in state.foods} end)

    # Tails that will vacate this tick (a snake that eats keeps its tail).
    vacating =
      for {id, p} <- players, not eating[id], into: MapSet.new(), do: List.last(p.body)

    blockers = MapSet.difference(all_bodies, vacating)

    head_counts = Enum.frequencies(Map.values(heads))

    {players, eaten} =
      Enum.reduce(players, {%{}, []}, fn {id, p}, {acc, eaten} ->
        head = heads[id]

        dead? =
          out_of_bounds?(head) or MapSet.member?(blockers, head) or
            Map.get(head_counts, head, 0) > 1

        cond do
          dead? ->
            {Map.put(acc, id, respawn(p, occupied(acc))), eaten}

          eating[id] ->
            {Map.put(acc, id, %{p | body: [head | p.body], score: p.score + 1}), [head | eaten]}

          true ->
            new_body = [head | Enum.drop(p.body, -1)]
            {Map.put(acc, id, %{p | body: new_body}), eaten}
        end
      end)

    foods = replenish_foods(state.foods -- eaten, players)
    %{state | players: players, foods: foods}
  end

  defp step_head({x, y}, :up), do: {x, y - 1}
  defp step_head({x, y}, :down), do: {x, y + 1}
  defp step_head({x, y}, :left), do: {x - 1, y}
  defp step_head({x, y}, :right), do: {x + 1, y}

  defp out_of_bounds?({x, y}), do: x < 0 or y < 0 or x >= @cols or y >= @rows

  defp opposite?(:up, :down), do: true
  defp opposite?(:down, :up), do: true
  defp opposite?(:left, :right), do: true
  defp opposite?(:right, :left), do: true
  defp opposite?(_, _), do: false

  # Snake / food placement ---------------------------------------------------

  defp respawn(p, occupied),
    do: %{p | body: spawn_body(occupied, :right), score: 0, dir: :right, pending: :right}

  # Spawn a horizontal snake of @start_len somewhere with room, avoiding
  # occupied cells. Falls back to a best-effort spot if the board is crowded.
  defp spawn_body(occupied, _dir) do
    candidate =
      Enum.find(random_cells(), fn {x, y} ->
        x >= @start_len and
          Enum.all?(0..(@start_len - 1), &(not MapSet.member?(occupied, {x - &1, y})))
      end)

    {hx, hy} = candidate || {@start_len, div(@rows, 2)}
    for i <- 0..(@start_len - 1), do: {hx - i, hy}
  end

  defp spawn_foods(existing, players) do
    replenish_foods(existing, players)
  end

  defp replenish_foods(foods, players) do
    taken = MapSet.union(occupied(players), MapSet.new(foods))

    Enum.reduce_while(random_cells(), {foods, taken}, fn cell, {fs, tk} ->
      if length(fs) >= @food_count do
        {:halt, {fs, tk}}
      else
        if MapSet.member?(tk, cell),
          do: {:cont, {fs, tk}},
          else: {:cont, {[cell | fs], MapSet.put(tk, cell)}}
      end
    end)
    |> elem(0)
  end

  defp occupied(players) do
    for {_id, p} <- players, p.body, cell <- p.body, into: MapSet.new(), do: cell
  end

  defp random_cells do
    for(x <- 0..(@cols - 1), y <- 0..(@rows - 1), do: {x, y}) |> Enum.shuffle()
  end

  defp random_name do
    "#{Enum.random(@adjectives)}-#{Enum.random(@animals)}"
  end

  # Keep names tidy: trimmed, single-line, capped at 20 chars. Blank or
  # inappropriate names are rejected and the previous name is kept.
  defp clean_name(name, fallback) when is_binary(name) do
    cleaned =
      name
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
      |> String.slice(0, 20)

    cond do
      cleaned == "" -> fallback
      profane?(cleaned) -> fallback
      true -> cleaned
    end
  end

  defp clean_name(_name, fallback), do: fallback

  # Blocklist of profanity/slur roots. We normalize the candidate first —
  # lowercase, de-leet common substitutions, strip non-letters — so tricks like
  # "f_u_c_k", "sh1t" or "@ss" are still caught. Deliberately errs toward
  # blocking; these are public, broadcast names.
  @leet %{
    "0" => "o",
    "1" => "i",
    "3" => "e",
    "4" => "a",
    "5" => "s",
    "7" => "t",
    "8" => "b",
    "@" => "a",
    "$" => "s",
    "!" => "i",
    "|" => "i",
    "+" => "t"
  }
  # Roots are matched as substrings of the normalized name, so each root also
  # catches its variants (e.g. "fuck" → motherfucker, fuckface). Deliberately
  # OMITS high-false-positive fragments that live inside innocent words — bare
  # "ass" (bass/class), "cock" (peacock), "coon" (raccoon), "spic" (spice),
  # "jap" (japan), "gyp" (egypt), "hell", "damn" — since names are user-visible
  # and this is an animal-themed game.
  @banned ~w(
    fuck shit bitch biatch cunt asshole dumbass jackass dick pussy twat
    wank whore slut skank thot prick bollock arse bugger minge gash cum
    jizz dildo blowjob handjob boner horny masturbat orgasm penis vagina
    scrotum ballsack nutsack clit anus cocksuck douche fondle smut bastard
    nigger nigga fag retard spastic spaz trann shemale dyke kike chink
    gook wetback beaner paki wop dago negro raghead towelhead chinaman
    redskin coolie sambo jigaboo mongoloid cripple midget
    rape molest pedo incest bestial nazi hitler heil klux whitepower
  )

  defp profane?(name) do
    norm =
      name
      |> String.downcase()
      |> String.graphemes()
      |> Enum.map(&Map.get(@leet, &1, &1))
      |> Enum.join()
      |> String.replace(~r/[^a-z]/, "")

    Enum.any?(@banned, &String.contains?(norm, &1))
  end

  # Broadcast / serialization ------------------------------------------------

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Blog.PubSub, @topic, {:snake_state, public(state)})
  end

  # A trimmed, render-friendly view of the state.
  defp public(state) do
    players =
      state.players
      |> Enum.map(fn {id, p} ->
        %{id: id, name: p.name, color: p.color, score: p.score, body: p.body}
      end)
      |> Enum.sort_by(& &1.score, :desc)

    %{cols: @cols, rows: @rows, players: players, foods: state.foods}
  end
end
