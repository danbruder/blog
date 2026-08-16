defmodule Blog.KudosTest do
  use Blog.DataCase, async: true

  alias Blog.Content
  alias Blog.Kudos

  describe "build_email/2" do
    test "returns :no_kudos when nothing was given" do
      assert Kudos.build_email(%{total: 0, by_path: []}, DateTime.utc_now()) == :no_kudos
    end

    test "resolves each path to its post title and links back to it" do
      {:ok, _post} =
        Content.create_post(%{
          title: "How To Delete A Git Tag",
          slug: "how-to-delete-a-git-tag",
          kind: "post",
          published: true
        })

      summary = %{
        total: 3,
        by_path: [
          %{path: "/blog/how-to-delete-a-git-tag", count: 2},
          %{path: "/notes/missing-note", count: 1}
        ]
      }

      email = Kudos.build_email(summary, ~U[2026-08-16 12:00:00Z])

      assert email.subject =~ "3 kudos given today"
      assert email.html =~ "How To Delete A Git Tag"
      assert email.html =~ "http://localhost:4002/blog/how-to-delete-a-git-tag"
      assert email.html =~ "2 kudos"
      # No post exists for this path (e.g. deleted since) -- falls back to
      # showing the raw path rather than dropping the line.
      assert email.html =~ "/notes/missing-note"
      assert email.text =~ "How To Delete A Git Tag"
    end

    test "singularizes for exactly one kudo" do
      summary = %{total: 1, by_path: [%{path: "/blog/one-kudo", count: 1}]}

      email = Kudos.build_email(summary, ~U[2026-08-16 12:00:00Z])

      assert email.subject =~ "1 kudo given today"
      assert email.html =~ "&mdash; 1 kudo\n"
      refute email.html =~ "1 kudos"
    end
  end

  describe "today_range/1" do
    test "start is midnight in the digest timezone, converted to UTC" do
      # 2026-08-16 15:00 UTC is 11:00 EDT (America/New_York is UTC-4 in August).
      now = ~U[2026-08-16 15:00:00Z]

      {from, to} = Kudos.today_range(now)

      assert to == now
      assert from == ~U[2026-08-16 04:00:00Z]
    end
  end

  describe "deliver_digest/2" do
    test "returns :no_kudos and sends nothing when there were no kudos" do
      # unique_base/0, not DateTime.utc_now/0: other test files' real kudos
      # events land around "now" (e.g. BlogWeb.KudosControllerTest), and
      # kudos_summary/2 counts every path, so a "now" window here would be
      # flaky against those running concurrently.
      base = unique_base()

      assert Kudos.deliver_digest(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute)) ==
               :no_kudos
    end

    test "returns an error rather than sending when Resend isn't configured" do
      # config/test.exs doesn't set Blog.Resend's api_key/from, matching how
      # a fresh deploy behaves without RESEND_API_KEY/RESEND_FROM_EMAIL set
      # -- this never touches the network.
      base = unique_base()
      insert_kudos("/blog/some-post", base)

      assert Kudos.deliver_digest(DateTime.add(base, -1, :minute), DateTime.add(base, 1, :minute)) ==
               {:error, :missing_api_key}
    end
  end

  defp insert_kudos(path, %DateTime{} = occurred_at) do
    {:ok, _columns, _rows} =
      Blog.Analytics.query(
        "INSERT INTO events (occurred_at_us, event_name, path) VALUES ($1, 'kudos', $2)",
        [DateTime.to_unix(occurred_at, :microsecond), path]
      )
  end

  defp unique_base do
    DateTime.add(~U[2021-01-01 00:00:00Z], System.unique_integer([:positive]) * 3600, :second)
  end
end
