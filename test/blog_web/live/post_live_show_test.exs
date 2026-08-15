defmodule BlogWeb.PostLive.ShowTest do
  use BlogWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Blog.Analytics
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

  test "renders a note at /notes/:slug without the newsletter form or 3D CTA", %{
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
    refute html =~ "Explore this site in 3D"
  end

  test "a post's footer links to the 3D site and not to the snake game", %{conn: conn} do
    {:ok, _post} =
      Content.create_post(%{
        title: "My Post",
        slug: "my-post-3d",
        body: "Body",
        kind: "post",
        published: true,
        published_at: ~D[2024-01-01]
      })

    {:ok, _view, html} = live(conn, ~p"/blog/my-post-3d")

    assert html =~ "Explore this site in 3D"
    refute html =~ "snake"
  end

  test "footer omits view counts and shows the kudos widget when a post has no traffic yet", %{
    conn: conn
  } do
    {:ok, _post} =
      Content.create_post(%{
        title: "Fresh Post",
        slug: "fresh-post",
        body: "Body",
        kind: "post",
        published: true,
        published_at: ~D[2024-01-01]
      })

    {:ok, _view, html} = live(conn, ~p"/blog/fresh-post")

    # The render reflects the count as of mount, before this very visit is
    # tracked (that happens in a handle_params hook right afterwards) -- so
    # a never-before-seen post still renders with no view counts shown.
    refute html =~ "views all time"
    assert html =~ "id=\"kudos\""
    assert html =~ "hold to give kudos"
  end

  test "footer shows view counts once there's prior traffic", %{conn: conn} do
    {:ok, _post} =
      Content.create_post(%{
        title: "Popular Post",
        slug: "popular-post",
        body: "Body",
        kind: "post",
        published: true,
        published_at: ~D[2024-01-01]
      })

    Analytics.track("page_view", %{path: "/blog/popular-post", session_id: "s1"})
    Analytics.track("page_view", %{path: "/blog/popular-post", session_id: "s2"})
    Analytics.flush()

    {:ok, _view, html} = live(conn, ~p"/blog/popular-post")

    assert html =~ "2 views all time"
    assert html =~ "2 in the last week"
  end

  test "kudos widget renders as already-given once the browser has kudos'd this post", %{
    conn: conn
  } do
    {:ok, _post} =
      Content.create_post(%{
        title: "Thanked Post",
        slug: "thanked-post",
        body: "Body",
        kind: "post",
        published: true,
        published_at: ~D[2024-01-01]
      })

    conn = post(conn, ~p"/kudos", %{"path" => "/blog/thanked-post"})
    assert %{"already" => false} = json_response(conn, 200)

    {:ok, _view, html} = live(conn, ~p"/blog/thanked-post")

    assert html =~ "data-given=\"true\""
    assert html =~ "Thanks!"
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
