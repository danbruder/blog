defmodule BlogWeb.KudosControllerTest do
  use BlogWeb.ConnCase, async: false

  alias Blog.Analytics

  test "POST /kudos records a kudos for the path and returns the new count", %{conn: conn} do
    path = "/blog/kudos-#{System.unique_integer([:positive])}"

    conn = post(conn, ~p"/kudos", %{"path" => path, "session_id" => "sailor-1"})

    assert %{"kudos" => 1, "already" => false} = json_response(conn, 200)

    {:ok, stats} = Analytics.post_stats(path)
    assert stats.kudos == 1
  end

  test "a second kudos for the same path from the same browser is a no-op", %{conn: conn} do
    path = "/notes/kudos-#{System.unique_integer([:positive])}"

    conn = post(conn, ~p"/kudos", %{"path" => path})
    assert %{"kudos" => 1, "already" => false} = json_response(conn, 200)

    # Reuses the same conn, so it carries the session cookie set by the
    # first request -- exactly what stops a double thumbs-up in the browser.
    conn = conn |> recycle() |> post(~p"/kudos", %{"path" => path})
    assert %{"kudos" => 1, "already" => true} = json_response(conn, 200)

    {:ok, stats} = Analytics.post_stats(path)
    assert stats.kudos == 1
  end

  test "rejects a path outside /blog/ or /notes/", %{conn: conn} do
    conn = post(conn, ~p"/kudos", %{"path" => "/admin"})

    assert %{"error" => _} = json_response(conn, 400)
  end

  test "rejects a request with no path", %{conn: conn} do
    conn = post(conn, ~p"/kudos", %{})

    assert %{"error" => _} = json_response(conn, 400)
  end
end
