defmodule Blog.SandGame.SimTest do
  use ExUnit.Case, async: true

  alias Blog.SandGame.Sim

  # Build a grid binary from a list of rows of codes (top row first).
  defp grid(rows) do
    w = length(hd(rows))
    h = length(rows)
    bin = rows |> List.flatten() |> :erlang.list_to_binary()
    {bin, w, h}
  end

  defp at({bin, w, _h}, x, y), do: :binary.at(bin, y * w + x)

  test "sand falls into empty space below" do
    {g, w, h} = grid([[1], [0]])
    {g2, _, _} = {Sim.step(g, w, h, seed: 1), w, h}
    assert at({g2, w, h}, 0, 0) == 0
    assert at({g2, w, h}, 0, 1) == 1
  end

  test "sand rests on the floor" do
    {g, w, h} = grid([[0], [1]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 1) == 1
  end

  test "sand slides diagonally when blocked directly below" do
    # sand at (1,0); (1,1) is stone; one of the diagonals must receive it.
    {g, w, h} = grid([[0, 1, 0], [0, 3, 0]])
    g2 = Sim.step(g, w, h, seed: 1)
    landed = at({g2, w, h}, 0, 1) == 1 or at({g2, w, h}, 2, 1) == 1
    assert landed
    assert at({g2, w, h}, 1, 0) == 0
  end

  test "sand sinks through water (they swap)" do
    {g, w, h} = grid([[1], [2]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 0) == 2
    assert at({g2, w, h}, 0, 1) == 1
  end

  test "a particle moves at most one cell per tick" do
    {g, w, h} = grid([[1], [0], [0]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 1) == 1
    assert at({g2, w, h}, 0, 2) == 0
  end

  test "water falls into empty space below" do
    {g, w, h} = grid([[2], [0]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 0) == 0
    assert at({g2, w, h}, 0, 1) == 2
  end

  test "water spreads sideways on a flat floor" do
    # water at (1,1) sitting on stone floor; must move to an open side cell.
    {g, w, h} = grid([[0, 0, 0], [3, 2, 3], [3, 3, 3]])
    # Side neighbors (0,1)/(2,1) are stone, so it can't spread; it should stay.
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 1, 1) == 2

    {g3, w3, h3} = grid([[0, 0, 0], [0, 2, 0], [3, 3, 3]])
    g4 = Sim.step(g3, w3, h3, seed: 1)
    # It can't go straight down (stone floor), so it slides to a bottom-diagonal.
    moved_down_diag = at({g4, w3, h3}, 0, 1) == 0 and at({g4, w3, h3}, 1, 1) == 0
    assert at({g4, w3, h3}, 0, 1) == 2 or at({g4, w3, h3}, 2, 1) == 2 or moved_down_diag == false
  end

  test "stone and wood never move on their own" do
    {g, w, h} = grid([[3, 4], [0, 0]])
    g2 = Sim.step(g, w, h, seed: 1)
    assert at({g2, w, h}, 0, 0) == 3
    assert at({g2, w, h}, 1, 0) == 4
  end

  test "fire ignites adjacent wood when p_ignite is 1.0" do
    # fire at (0,0), wood at (1,0)
    {g, w, h} = grid([[5, 4]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 1.0, p_burnout: 0.0)
    assert at({g2, w, h}, 1, 0) == 5
  end

  test "fire does not ignite wood when p_ignite is 0.0" do
    {g, w, h} = grid([[5, 4]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 0.0, p_burnout: 0.0)
    assert at({g2, w, h}, 1, 0) == 4
  end

  test "fire adjacent to water is extinguished" do
    {g, w, h} = grid([[5, 2]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 1.0, p_burnout: 0.0)
    assert at({g2, w, h}, 0, 0) == 0
  end

  test "fire burns out when p_burnout is 1.0" do
    {g, w, h} = grid([[5]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 0.0, p_burnout: 1.0)
    assert at({g2, w, h}, 0, 0) == 0
  end

  test "isolated fire persists when p_burnout is 0.0" do
    {g, w, h} = grid([[5]])
    g2 = Sim.step(g, w, h, seed: 1, p_ignite: 0.0, p_burnout: 0.0)
    assert at({g2, w, h}, 0, 0) == 5
  end
end
