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
end
