defmodule BlogWeb.NoteLive.IndexTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Blog.Content

  test "renders published notes, not posts", %{conn: conn} do
    {:ok, _note} =
      Content.create_post(%{
        title: "My Note",
        slug: "my-note",
        body: "hello",
        kind: "note",
        published: true,
        published_at: ~D[2024-01-01]
      })

    {:ok, _post} =
      Content.create_post(%{
        title: "My Post",
        slug: "my-post",
        body: "hello",
        kind: "post",
        published: true,
        published_at: ~D[2024-01-01]
      })

    {:ok, _view, html} = live(conn, ~p"/notes")

    assert html =~ "My Note"
    refute html =~ "My Post"
  end

  test "sidebar marks the current section's nav link active", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/notes")

    # The active nav link carries the paper-3 marker; inactive links use hover:* instead.
    assert html =~ "bg-paper-3 font-semibold !text-ink"
  end
end
