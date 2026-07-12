defmodule BlogWeb.PodcastLive.IndexTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "shows the Software Unscripted appearance with a listen link", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/podcasts")

    assert html =~ "Podcasts"
    assert html =~ "Software Unscripted"
    assert html =~ "open.spotify.com/episode/6cnAHvdCXedoHxG4w9pWOV"
  end
end
