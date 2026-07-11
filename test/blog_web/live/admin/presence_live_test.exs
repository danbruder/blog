defmodule BlogWeb.Admin.PresenceLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias BlogWeb.Admin.PresenceLive

  test "GET /admin/viewers redirects to login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, ~p"/admin/viewers")
  end

  test "renders the viewers page when authenticated", %{conn: conn} do
    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:admin_authenticated, true)

    {:ok, _view, html} = live(conn, ~p"/admin/viewers")

    assert html =~ "Viewers"
  end

  test "summarize/1 groups presences by country and sorts by count descending" do
    presences = [
      {"s1", %{metas: [%{country: "US"}]}},
      {"s2", %{metas: [%{country: "US"}]}},
      {"s3", %{metas: [%{country: "CA"}]}}
    ]

    assert PresenceLive.summarize(presences) == [{"US", 2}, {"CA", 1}]
  end

  test "summarize/1 buckets missing country as Unknown" do
    presences = [{"s1", %{metas: [%{country: nil}]}}]

    assert PresenceLive.summarize(presences) == [{"Unknown", 1}]
  end

  test "flag/1 renders a regional indicator emoji for a two-letter code" do
    assert PresenceLive.flag("US") == "🇺🇸"
  end

  test "flag/1 falls back to a white flag for anything else" do
    assert PresenceLive.flag("Unknown") == "🏳️"
  end
end
