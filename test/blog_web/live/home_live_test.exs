defmodule BlogWeb.HomeLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Blog.Content

  test "renders the landing with a band per subsection", %{conn: conn} do
    {:ok, _post} =
      Content.create_post(%{title: "My First Post", slug: "my-first-post", body: "hello", kind: "post", published: true, published_at: ~D[2024-01-01]})

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Hi, I&#39;m Dan"
    assert html =~ "Writing"
    assert html =~ "Notes"
    assert html =~ "Games"
    assert html =~ "Podcasts"
    assert html =~ "Projects"
    assert html =~ ~s(href="/writing")
    assert html =~ "My First Post"
  end
end
