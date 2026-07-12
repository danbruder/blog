defmodule BlogWeb.HomeLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Blog.Content

  test "renders latest published posts", %{conn: conn} do
    {:ok, _post} =
      Content.create_post(%{
        title: "My First Post",
        slug: "my-first-post",
        body: "hello",
        kind: "post",
        published: true,
        published_at: ~D[2024-01-01]
      })

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "My First Post"
    assert html =~ "Writing"
    refute html =~ "Hi, I&#39;m Dan"
  end
end
