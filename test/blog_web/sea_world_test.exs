defmodule BlogWeb.SeaWorldTest do
  use Blog.DataCase, async: true

  alias BlogWeb.SeaWorld

  test "always includes the harbor at the origin" do
    harbor = Enum.find(SeaWorld.islands(), &(&1.path == "/"))
    assert harbor.section == "harbor"
    assert harbor.x == 0.0
    assert harbor.z == 0.0
    assert harbor.title == "Harbor"
  end

  test "includes the fixed section index islands" do
    paths = SeaWorld.islands() |> Enum.map(& &1.path)

    for p <- ["/writing", "/notes", "/podcasts", "/projects", "/games"] do
      assert p in paths, "expected island for #{p}"
    end
  end

  test "includes an island for each published post and note" do
    {:ok, post} =
      Blog.Content.create_post(%{
        title: "Hello Sea",
        slug: "hello-sea",
        kind: "post",
        published: true
      })

    {:ok, _note} =
      Blog.Content.create_post(%{
        title: "A Note",
        slug: "a-note",
        kind: "note",
        published: true
      })

    by_path = SeaWorld.islands() |> Map.new(&{&1.path, &1})

    assert by_path["/blog/hello-sea"].title == "Hello Sea"
    assert by_path["/blog/hello-sea"].section == "writing"
    assert by_path["/notes/a-note"].title == "A Note"
    assert by_path["/notes/a-note"].section == "notes"

    # Positions are deterministic and non-origin for non-harbor islands.
    assert {by_path["/blog/hello-sea"].x, by_path["/blog/hello-sea"].z} != {0.0, 0.0}
    refute post.id == nil
  end

  test "positions are stable across calls" do
    a = SeaWorld.islands() |> Map.new(&{&1.path, {&1.x, &1.z}})
    b = SeaWorld.islands() |> Map.new(&{&1.path, {&1.x, &1.z}})
    assert a == b
  end

  test "unpublished posts get no island" do
    {:ok, _} =
      Blog.Content.create_post(%{
        title: "Secret",
        slug: "secret-draft",
        kind: "post",
        published: false
      })

    refute Enum.any?(SeaWorld.islands(), &(&1.path == "/blog/secret-draft"))
  end
end
