defmodule BlogWeb.FeedControllerTest do
  # async: false — these tests write posts, and the SQLite sandbox is flaky
  # under concurrent writers (see the pre-existing async write tests).
  use BlogWeb.ConnCase, async: false

  alias Blog.Content

  @post %{
    title: "My First Post",
    slug: "my-first-post",
    body: "Hello **world**.",
    kind: "post",
    published: true,
    published_at: ~D[2026-01-15]
  }

  test "GET /rss.xml returns an RSS feed with published posts", %{conn: conn} do
    {:ok, _} = Content.create_post(@post)

    conn = get(conn, ~p"/rss.xml")

    assert response_content_type(conn, :xml) =~ "application/rss+xml"
    body = response(conn, 200)
    assert body =~ ~s(<rss version="2.0")
    assert body =~ "<title>My First Post</title>"
    assert body =~ "/blog/my-first-post</link>"
    assert body =~ "Thu, 15 Jan 2026 00:00:00 +0000"
    assert body =~ "Hello <strong>world</strong>"
  end

  test "GET /feed.xml also serves the RSS feed", %{conn: conn} do
    conn = get(conn, ~p"/feed.xml")
    assert response(conn, 200) =~ ~s(<rss version="2.0")
  end

  test "GET /atom.xml redirects to /rss.xml", %{conn: conn} do
    conn = get(conn, ~p"/atom.xml")
    assert redirected_to(conn, 301) == ~p"/rss.xml"
  end

  test "GET /sitemap.xml lists the home page and published posts", %{conn: conn} do
    {:ok, _} = Content.create_post(@post)

    conn = get(conn, ~p"/sitemap.xml")
    body = response(conn, 200)

    assert body =~ "<urlset"
    assert body =~ "/blog/my-first-post</loc>"
  end
end
