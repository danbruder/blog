defmodule BlogWeb.PostLive.ShowTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Blog.Content

  test "renders a published post", %{conn: conn} do
    {:ok, _post} =
      Content.create_post(%{
        title: "My Post",
        slug: "my-post",
        body: "# Heading\n\nSome **bold** text.",
        kind: "post",
        published: true,
        published_at: ~D[2024-01-01]
      })

    {:ok, _view, html} = live(conn, ~p"/blog/my-post")

    assert html =~ "My Post"
    assert html =~ "<strong>bold</strong>"
  end

  test "renders a note at /notes/:slug without the newsletter form or snake footer", %{
    conn: conn
  } do
    {:ok, _note} =
      Content.create_post(%{
        title: "My Note",
        slug: "my-note",
        body: "Some *note* body.",
        kind: "note",
        published: true,
        published_at: ~D[2024-01-01]
      })

    {:ok, _view, html} = live(conn, ~p"/notes/my-note")

    assert html =~ "My Note"
    refute html =~ "Newsletter signup"
    refute html =~ "have a go at the game of"
  end

  test "redirects home for a missing slug", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/blog/does-not-exist")
  end

  test "redirects home for an unpublished slug", %{conn: conn} do
    {:ok, _post} =
      Content.create_post(%{
        title: "Draft",
        slug: "a-draft",
        body: "shh",
        kind: "post",
        published: false
      })

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/blog/a-draft")
  end
end
