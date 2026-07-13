defmodule BlogWeb.WritingLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Blog.Content

  test "lists published posts, not notes", %{conn: conn} do
    {:ok, _} = Content.create_post(%{title: "A Post", slug: "a-post", body: "x", kind: "post", published: true, published_at: ~D[2024-01-01]})
    {:ok, _} = Content.create_post(%{title: "A Note", slug: "a-note", body: "x", kind: "note", published: true, published_at: ~D[2024-01-01]})
    {:ok, _view, html} = live(conn, ~p"/writing")
    assert html =~ "A Post"
    refute html =~ "A Note"
  end

  test "is also served at the root path", %{conn: conn} do
    {:ok, _} = Content.create_post(%{title: "A Post", slug: "a-post", body: "x", kind: "post", published: true, published_at: ~D[2024-01-01]})
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "A Post"
  end
end
