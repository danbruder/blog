defmodule Blog.Kudos do
  @moduledoc """
  Assembles and sends the "kudos given today" digest email -- see
  `Blog.Kudos.DailyDigestWorker`, which runs this once a day via Oban Cron
  (`config :blog, Oban`). Nothing is sent on a day with zero kudos.
  """

  require Logger

  alias Blog.Analytics
  alias Blog.Content

  @doc """
  The `[start of today, now)` window for the digest, in the timezone the
  Cron job is scheduled against (`config :blog, :kudos_digest_timezone`) --
  so "today" always means the calendar day the worker is running at the
  end of, however far into it `now` falls.

  Built from a `Date` + midnight `Time` (rather than just zeroing `now`'s
  hour/minute/second) so the one or two days a year U.S. Eastern time
  shifts for DST -- always at 2am, never at midnight -- can't skew the
  window's start by an hour.
  """
  def today_range(now \\ DateTime.utc_now()) do
    timezone = Application.fetch_env!(:blog, :kudos_digest_timezone)
    today = now |> DateTime.shift_zone!(timezone) |> DateTime.to_date()

    case DateTime.new(today, ~T[00:00:00], timezone) do
      {:ok, midnight} -> {DateTime.shift_zone!(midnight, "Etc/UTC"), now}
      # Midnight is never ambiguous/skipped for a DST transition (those
      # happen at 2am), but fall back to picking either side rather than
      # crashing the digest job if that ever stops being true somewhere.
      {:ambiguous, midnight, _} -> {DateTime.shift_zone!(midnight, "Etc/UTC"), now}
      {:gap, _before, midnight} -> {DateTime.shift_zone!(midnight, "Etc/UTC"), now}
    end
  end

  @doc """
  Sends the digest for kudos given in `[from, to)`. Returns:

    * `:no_kudos` -- nothing was sent because no kudos were given
    * `:ok` -- the email was sent
    * `{:error, reason}` -- the kudos lookup or the send itself failed
  """
  def deliver_digest(from, to) do
    with {:ok, summary} <- Analytics.kudos_summary(from, to) do
      case build_email(summary, from) do
        :no_kudos -> :no_kudos
        email -> send_digest(email)
      end
    end
  end

  defp send_digest(email) do
    case Application.get_env(:blog, :kudos_digest_to) do
      to when is_binary(to) and to != "" ->
        Blog.Resend.send_email(Map.put(email, :to, to))

      _ ->
        Logger.warning(
          "Blog.Kudos: no digest recipient configured (:kudos_digest_to / KUDOS_DIGEST_TO_EMAIL); skipping send"
        )

        {:error, :missing_recipient}
    end
  end

  @doc """
  Builds the digest email for a `kudos_summary/2` result, or returns
  `:no_kudos` if none were given. `window_start` is the `from` half of the
  `today_range/1` tuple -- the UTC instant for local midnight -- which is
  shifted back to the local calendar date here for display.
  """
  def build_email(%{total: 0}, _window_start), do: :no_kudos

  def build_email(%{total: total, by_path: by_path}, window_start) do
    timezone = Application.fetch_env!(:blog, :kudos_digest_timezone)
    date = window_start |> DateTime.shift_zone!(timezone) |> DateTime.to_date()
    lines = Enum.map(by_path, &digest_line/1)

    %{
      subject: subject(total, date),
      html: render_html(total, date, lines),
      text: render_text(total, date, lines)
    }
  end

  defp digest_line(%{path: path, count: count}) do
    %{title: post_title(path), url: site_url() <> path, count: count}
  end

  defp post_title(path) do
    with slug when is_binary(slug) <- post_slug(path),
         %Content.Post{title: title} <- Content.get_by_slug(slug) do
      title
    else
      # Falls back to the raw path if it doesn't look like a post/note URL,
      # or the post has since been deleted/renamed -- either way, still
      # worth reporting rather than dropping the line.
      _ -> path
    end
  end

  defp post_slug("/blog/" <> slug), do: slug
  defp post_slug("/notes/" <> slug), do: slug
  defp post_slug(_path), do: nil

  defp site_url, do: Application.fetch_env!(:blog, :site_url)

  defp subject(total, date) do
    "#{total} #{pluralize(total, "kudo", "kudos")} given today (#{Calendar.strftime(date, "%B %-d, %Y")})"
  end

  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_count, _singular, plural), do: plural

  defp render_text(total, date, lines) do
    header =
      "#{total} #{pluralize(total, "kudo", "kudos")} given on #{Calendar.strftime(date, "%B %-d, %Y")}:\n"

    body =
      Enum.map_join(lines, "\n", fn %{title: title, url: url, count: count} ->
        "  - #{title} (#{count} #{pluralize(count, "kudo", "kudos")}) -- #{url}"
      end)

    header <> "\n" <> body <> "\n"
  end

  defp render_html(total, date, lines) do
    items =
      Enum.map_join(lines, "\n", fn %{title: title, url: url, count: count} ->
        """
        <li>
          <a href="#{escape(url)}">#{escape(title)}</a>
          &mdash; #{count} #{pluralize(count, "kudo", "kudos")}
        </li>
        """
      end)

    """
    <div style="font-family: sans-serif; max-width: 480px;">
      <h1 style="font-size: 1.25rem;">
        #{total} #{pluralize(total, "kudo", "kudos")} given today
      </h1>
      <p style="color: #666;">#{escape(Calendar.strftime(date, "%B %-d, %Y"))}</p>
      <ul style="padding-left: 1.25rem;">
        #{items}
      </ul>
    </div>
    """
  end

  defp escape(string) do
    string |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end
end
