defmodule BlogWeb.Admin.AnalyticsLive do
  use BlogWeb, :live_view

  alias Blog.Analytics

  @ranges [
    {"24h", "Last 24 hours", 1},
    {"7d", "Last 7 days", 7},
    {"30d", "Last 30 days", 30},
    {"90d", "Last 90 days", 90},
    {"all", "All time", nil}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Analytics")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    range =
      if Enum.any?(@ranges, fn {key, _label, _days} -> key == params["range"] end),
        do: params["range"],
        else: "7d"

    referrer_filter = params["referrer"] || ""

    {:noreply,
     socket
     |> assign(range: range, referrer_filter: referrer_filter, ranges: @ranges)
     |> load_report()}
  end

  @impl true
  def handle_event("filter", %{"range" => range, "referrer" => referrer}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/admin/analytics?#{%{range: range, referrer: referrer}}")}
  end

  defp load_report(socket) do
    {from, to} = range_bounds(socket.assigns.range)
    opts = [referrer_contains: blank_to_nil(socket.assigns.referrer_filter)]

    case Analytics.stats(from, to, opts) do
      {:ok, report} ->
        assign(socket,
          summary: report.summary,
          top_paths: report.top_paths,
          top_countries: report.top_countries,
          top_referrers: report.top_referrers
        )

      {:error, _reason} ->
        assign(socket,
          summary: %{views: 0, sessions: 0, avg_duration_seconds: nil},
          top_paths: [],
          top_countries: [],
          top_referrers: []
        )
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp range_bounds(range) do
    now = DateTime.utc_now()
    {_key, _label, days} = Enum.find(@ranges, fn {key, _label, _days} -> key == range end)
    from = if days, do: DateTime.add(now, -days, :day), else: ~U[2020-01-01 00:00:00Z]
    {from, now}
  end

  defp format_duration(nil), do: "--"

  defp format_duration(seconds) do
    total = round(seconds)
    minutes = div(total, 60)
    secs = rem(total, 60)
    "#{minutes}m #{secs}s"
  end

  defp flag(<<a, b>>) when a in ?A..?Z and b in ?A..?Z,
    do: <<a + 0x1F1A5::utf8, b + 0x1F1A5::utf8>>

  defp flag(_), do: "🏳️"

  @impl true
  def render(assigns) do
    ~H"""
    <.page_body>
      <div class="mx-auto max-w-3xl">
        <div class="mb-8 flex items-center justify-between gap-4">
          <h1 class="font-display text-[28px] font-bold tracking-[-0.03em] text-ink">Analytics</h1>
          <div class="flex items-center gap-4">
            <.link
              navigate={~p"/admin"}
              class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
            >
              Posts
            </.link>
            <.link
              navigate={~p"/admin/viewers"}
              class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
            >
              Viewers
            </.link>
            <.link
              href={~p"/admin/logout"}
              method="delete"
              class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
            >
              Log out
            </.link>
          </div>
        </div>

        <form id="analytics-filter" phx-change="filter" class="mb-8 flex flex-wrap items-end gap-4">
          <.input
            type="select"
            name="range"
            label="Time range"
            value={@range}
            options={Enum.map(@ranges, fn {key, label, _days} -> {label, key} end)}
          />
          <.input
            type="text"
            name="referrer"
            label="Referrer contains"
            value={@referrer_filter}
            placeholder="e.g. google"
          />
        </form>

        <div class="mb-10 grid grid-cols-3 gap-4 border-y border-ink py-6 text-center">
          <div>
            <div class="mark font-display text-[28px] font-bold text-ink">{@summary.views}</div>
            <div class="label mt-1">Page views</div>
          </div>
          <div>
            <div class="mark font-display text-[28px] font-bold text-ink">{@summary.sessions}</div>
            <div class="label mt-1">Sessions</div>
          </div>
          <div>
            <div class="mark font-display text-[28px] font-bold text-ink">
              {format_duration(@summary.avg_duration_seconds)}
            </div>
            <div class="label mt-1">Avg time on page</div>
          </div>
        </div>

        <div class="grid gap-10 sm:grid-cols-2">
          <section>
            <h2 class="label mb-3">Top pages</h2>
            <div :if={@top_paths == []} class="text-[13px] text-ink-3">No page views yet.</div>
            <div class="divide-y divide-rule border-t border-ink">
              <div :for={row <- @top_paths} class="flex items-center justify-between gap-4 py-2.5">
                <span class="truncate text-[13px] text-ink">{row.path}</span>
                <span class="shrink-0 text-[13px] text-ink-2">
                  {row.views} views &middot; {format_duration(row.avg_duration_seconds)}
                </span>
              </div>
            </div>
          </section>

          <section>
            <h2 class="label mb-3">Top countries</h2>
            <div :if={@top_countries == []} class="text-[13px] text-ink-3">No page views yet.</div>
            <div class="divide-y divide-rule border-t border-ink">
              <div :for={row <- @top_countries} class="flex items-center justify-between gap-4 py-2.5">
                <span class="text-[13px] text-ink">{flag(row.country)} {row.country}</span>
                <span class="shrink-0 text-[13px] text-ink-2">{row.sessions} sessions</span>
              </div>
            </div>
          </section>

          <section class="sm:col-span-2">
            <h2 class="label mb-3">Top referrers</h2>
            <div :if={@top_referrers == []} class="text-[13px] text-ink-3">No page views yet.</div>
            <div class="divide-y divide-rule border-t border-ink">
              <div :for={row <- @top_referrers} class="flex items-center justify-between gap-4 py-2.5">
                <span class="text-[13px] text-ink">{row.source}</span>
                <span class="shrink-0 text-[13px] text-ink-2">{row.sessions} sessions</span>
              </div>
            </div>
          </section>
        </div>
      </div>
    </.page_body>
    """
  end
end
