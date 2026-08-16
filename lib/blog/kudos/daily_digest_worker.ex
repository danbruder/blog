defmodule Blog.Kudos.DailyDigestWorker do
  @moduledoc """
  Oban Cron job (`config :blog, Oban`'s crontab) that sends the "kudos
  given today" digest email once a day. See `Blog.Kudos.deliver_digest/2`
  -- nothing is sent, and this still succeeds, on a day with zero kudos.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Blog.Kudos

  @impl Oban.Worker
  def perform(_job) do
    {from, to} = Kudos.today_range()

    case Kudos.deliver_digest(from, to) do
      :ok ->
        :ok

      :no_kudos ->
        :ok

      {:error, reason} = error ->
        Logger.error("Blog.Kudos.DailyDigestWorker: failed to send digest: #{inspect(reason)}")
        error
    end
  end
end
