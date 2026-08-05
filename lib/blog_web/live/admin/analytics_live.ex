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

  # Sentinel written into the `referrer` query param when a "Direct" row is
  # clicked, since "no referrer" can't be expressed as a substring to search
  # for the way a real host can.
  @direct_referrer "direct"

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

    {:noreply,
     socket
     |> assign(
       range: range,
       referrer_filter: params["referrer"] || "",
       path_filter: params["path"] || "",
       country_filter: params["country"] || "",
       ranges: @ranges
     )
     |> load_report()}
  end

  # The range/referrer form -- text-box driven, so it only knows about its
  # own two fields and relies on us to carry the click-driven filters along.
  @impl true
  def handle_event("filter", %{"range" => range, "referrer" => referrer}, socket) do
    {:noreply, push_patch(socket, to: filter_path(socket, %{range: range, referrer: referrer}))}
  end

  # Clicking a row in one of the breakdown lists turns it into a filter.
  def handle_event("set_filter", %{"field" => field, "value" => value}, socket) do
    {:noreply, push_patch(socket, to: filter_path(socket, %{filter_key(field) => value}))}
  end

  def handle_event("clear_filter", %{"field" => field}, socket) do
    {:noreply, push_patch(socket, to: filter_path(socket, %{filter_key(field) => ""}))}
  end

  def handle_event("reset_filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: filter_path(socket, %{path: "", country: "", referrer: ""}))}
  end

  defp filter_key("path"), do: :path
  defp filter_key("country"), do: :country
  defp filter_key("referrer"), do: :referrer

  # Builds the analytics URL for the current filter state, overridden with
  # whatever the triggering event changed -- so e.g. clicking a country
  # keeps whatever path/referrer filter was already active.
  defp filter_path(socket, overrides) do
    params =
      %{
        range: socket.assigns.range,
        referrer: socket.assigns.referrer_filter,
        path: socket.assigns.path_filter,
        country: socket.assigns.country_filter
      }
      |> Map.merge(overrides)

    ~p"/admin/analytics?#{params}"
  end

  defp load_report(socket) do
    {from, to} = range_bounds(socket.assigns.range)

    opts =
      [
        # Higher than Blog.Analytics's own default of 20: with click-to-filter
        # now inviting more distinct paths/countries/referrers into view, a
        # tighter cap made rows quietly disappear off the bottom of the list.
        limit: 50,
        path: blank_to_nil(socket.assigns.path_filter),
        country: blank_to_nil(socket.assigns.country_filter)
      ] ++ referrer_opts(socket.assigns.referrer_filter)

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

  defp referrer_opts(@direct_referrer), do: [direct: true]
  defp referrer_opts(value), do: [referrer_contains: blank_to_nil(value)]

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp any_filters?(assigns) do
    assigns.path_filter != "" or assigns.country_filter != "" or assigns.referrer_filter != ""
  end

  # What a clicked "Top referrers" row should filter by: the sentinel for
  # "Direct", the host itself otherwise.
  defp referrer_filter_value("Direct"), do: @direct_referrer
  defp referrer_filter_value(source), do: source

  defp referrer_filter_label(@direct_referrer), do: "Direct"
  defp referrer_filter_label(value), do: value

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

        <form id="analytics-filter" phx-change="filter" class="mb-4 flex flex-wrap items-end gap-4">
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

        <div :if={any_filters?(assigns)} class="mb-8 flex flex-wrap items-center gap-2">
          <span class="label">Filtered by</span>
          <button
            :if={@path_filter != ""}
            type="button"
            phx-click="clear_filter"
            phx-value-field="path"
            class="mark text-[12px]"
          >
            Path: {@path_filter} &times;
          </button>
          <button
            :if={@country_filter != ""}
            type="button"
            phx-click="clear_filter"
            phx-value-field="country"
            class="mark text-[12px]"
          >
            Country: {@country_filter} &times;
          </button>
          <button
            :if={@referrer_filter != ""}
            type="button"
            phx-click="clear_filter"
            phx-value-field="referrer"
            class="mark text-[12px]"
          >
            Referrer: {referrer_filter_label(@referrer_filter)} &times;
          </button>
          <button
            type="button"
            phx-click="reset_filters"
            class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
          >
            Reset
          </button>
        </div>

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
              <button
                :for={row <- @top_paths}
                type="button"
                phx-click="set_filter"
                phx-value-field="path"
                phx-value-value={row.path}
                class={[
                  "flex w-full items-center justify-between gap-4 py-2.5 text-left hover:bg-paper-2",
                  @path_filter == row.path && "bg-paper-2"
                ]}
              >
                <span class="truncate text-[13px] text-ink">{row.path}</span>
                <span class="shrink-0 text-[13px] text-ink-2">
                  {row.views} views &middot; {format_duration(row.avg_duration_seconds)}
                </span>
              </button>
            </div>
          </section>

          <section>
            <h2 class="label mb-3">Top countries</h2>
            <div :if={@top_countries == []} class="text-[13px] text-ink-3">No page views yet.</div>
            <div class="divide-y divide-rule border-t border-ink">
              <button
                :for={row <- @top_countries}
                type="button"
                phx-click="set_filter"
                phx-value-field="country"
                phx-value-value={row.country}
                class={[
                  "flex w-full items-center justify-between gap-4 py-2.5 text-left hover:bg-paper-2",
                  @country_filter == row.country && "bg-paper-2"
                ]}
              >
                <span class="text-[13px] text-ink">{flag(row.country)} {row.country}</span>
                <span class="shrink-0 text-[13px] text-ink-2">{row.sessions} sessions</span>
              </button>
            </div>
          </section>

          <section class="sm:col-span-2">
            <h2 class="label mb-3">Top referrers</h2>
            <div :if={@top_referrers == []} class="text-[13px] text-ink-3">No page views yet.</div>
            <div class="divide-y divide-rule border-t border-ink">
              <button
                :for={row <- @top_referrers}
                type="button"
                phx-click="set_filter"
                phx-value-field="referrer"
                phx-value-value={referrer_filter_value(row.source)}
                class={[
                  "flex w-full items-center justify-between gap-4 py-2.5 text-left hover:bg-paper-2",
                  @referrer_filter == referrer_filter_value(row.source) && "bg-paper-2"
                ]}
              >
                <span class="text-[13px] text-ink">{row.source}</span>
                <span class="shrink-0 text-[13px] text-ink-2">{row.sessions} sessions</span>
              </button>
            </div>
          </section>
        </div>
      </div>
    </.page_body>
    """
  end
end
