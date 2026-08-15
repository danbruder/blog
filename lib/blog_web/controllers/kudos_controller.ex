defmodule BlogWeb.KudosController do
  @moduledoc """
  Records a reader's "kudos" thumbs-up for a post (see the `Kudos` JS hook
  on `BlogWeb.PostLive.Show`), one per browser per post.

  "Once per browser" rides in the same signed/encrypted `_blog_key` session
  cookie the app already uses for `admin_seen` -- `session["kudos_paths"]`
  accumulates the paths a browser has already given kudos to, so a repeat
  POST for a path already in that list is a no-op that just reports the
  current count back. This is a courtesy, not a security boundary: clearing
  cookies resets it, same as any cookie-based "don't show me this again."
  """

  use BlogWeb, :controller

  # Only posts/notes can receive kudos -- matches the `/blog/:slug` and
  # `/notes/:slug` routes that render BlogWeb.PostLive.Show.
  @valid_prefixes ["/blog/", "/notes/"]

  def create(conn, %{"path" => path}) when is_binary(path) do
    if valid_path?(path) do
      given_paths = get_session(conn, "kudos_paths") || []
      already? = path in given_paths

      unless already? do
        Blog.Analytics.track_kudos(path, conn.body_params["session_id"])
      end

      {:ok, stats} = Blog.Analytics.post_stats(path)

      conn
      |> maybe_remember(path, given_paths, already?)
      |> json(%{kudos: stats.kudos, already: already?})
    else
      conn |> put_status(:bad_request) |> json(%{error: "invalid path"})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "missing path"})
  end

  defp valid_path?(path), do: Enum.any?(@valid_prefixes, &String.starts_with?(path, &1))

  defp maybe_remember(conn, _path, _given_paths, true), do: conn

  defp maybe_remember(conn, path, given_paths, false),
    do: put_session(conn, "kudos_paths", [path | given_paths])
end
