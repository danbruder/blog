defmodule Blog.SandGameTest do
  use ExUnit.Case, async: false

  alias Blog.SandGame

  test "grid/0 returns width*height bytes" do
    %{width: w, height: h} = SandGame.dims()
    assert byte_size(SandGame.grid()) == w * h
  end

  test "paint/2 stamps the given cells with the element code" do
    SandGame.clear()
    SandGame.paint([0, 1, 2], 3)
    grid = SandGame.grid()
    assert :binary.at(grid, 0) == 3
    assert :binary.at(grid, 1) == 3
    assert :binary.at(grid, 2) == 3
  end

  test "clear/0 empties the grid" do
    SandGame.paint([5, 6, 7], 1)
    SandGame.clear()
    grid = SandGame.grid()
    assert grid == :binary.copy(<<0>>, byte_size(grid))
  end

  test "join/1 returns viewer count and the current grid, and monitors the pid" do
    SandGame.clear()
    {count, grid} = SandGame.join(self())
    assert is_integer(count) and count >= 1
    assert byte_size(grid) == byte_size(SandGame.grid())
  end
end
