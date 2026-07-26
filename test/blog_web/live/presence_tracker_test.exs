defmodule BlogWeb.PresenceTrackerTest do
  use BlogWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  test "a connected viewer is tracked with a path in the meta", %{conn: conn} do
    {:ok, _lv, _html} = live(conn, "/writing")

    # Give the async track + handle_params a moment.
    metas =
      wait_for(fn ->
        case Presence.list(PresenceTracker.topic()) do
          m when map_size(m) > 0 -> m
          _ -> nil
        end
      end)

    [{_key, %{metas: [meta | _]}} | _] = Map.to_list(metas)
    assert meta.path == "/writing"
    assert Map.has_key?(meta, :sailor_id)
  end

  defp wait_for(fun, tries \\ 50) do
    case fun.() do
      nil when tries > 0 ->
        Process.sleep(20)
        wait_for(fun, tries - 1)

      result ->
        result
    end
  end
end
