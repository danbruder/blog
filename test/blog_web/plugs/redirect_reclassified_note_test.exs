defmodule BlogWeb.Plugs.RedirectReclassifiedNoteTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias BlogWeb.Plugs.RedirectReclassifiedNote

  test "301-redirects a reclassified slug to /notes/:slug" do
    conn =
      conn(:get, "/blog/how-to-delete-a-git-tag")
      |> RedirectReclassifiedNote.call([])

    assert conn.status == 301
    assert conn.halted
    assert get_resp_header(conn, "location") == ["/notes/how-to-delete-a-git-tag"]
  end

  test "passes through untouched for a slug not in the moved list" do
    conn =
      conn(:get, "/blog/advice-for-new-managers")
      |> RedirectReclassifiedNote.call([])

    refute conn.halted
    refute conn.status
  end

  test "passes through untouched for other paths" do
    conn =
      conn(:get, "/notes/how-to-delete-a-git-tag")
      |> RedirectReclassifiedNote.call([])

    refute conn.halted
    refute conn.status
  end
end
