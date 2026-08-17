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

  # Approximate {lat, lon} centroids for the "Where in the world" dot map,
  # keyed by the same ISO 3166-1 alpha-2 codes Blog.GeoIP resolves visitors
  # to. Deliberately just a lookup table rather than real country geometry
  # (see the map-style discussion this came out of): no third-party map
  # dataset to vendor/license/keep in sync, at the cost of plotting a point
  # rather than a shaded outline. A code with no entry here (or "Unknown",
  # for unresolved IPs) is simply left off the map -- it still shows up in
  # the Top countries list above.
  @country_centroids %{
    "US" => {39.8, -98.6},
    "CA" => {56.1, -106.3},
    "MX" => {23.6, -102.6},
    "GT" => {15.5, -90.2},
    "BZ" => {17.2, -88.5},
    "SV" => {13.8, -88.9},
    "HN" => {15.2, -86.2},
    "NI" => {12.9, -85.2},
    "CR" => {9.7, -83.8},
    "PA" => {8.5, -80.8},
    "CU" => {21.5, -79.5},
    "JM" => {18.1, -77.3},
    "HT" => {19.0, -72.3},
    "DO" => {18.7, -70.2},
    "BS" => {24.3, -76.0},
    "TT" => {10.7, -61.2},
    "BB" => {13.2, -59.5},
    "PR" => {18.2, -66.6},
    "CO" => {4.6, -74.1},
    "VE" => {8.0, -66.6},
    "GY" => {5.0, -58.9},
    "SR" => {4.0, -56.0},
    "BR" => {-10.0, -55.0},
    "EC" => {-1.8, -78.2},
    "PE" => {-9.2, -75.0},
    "BO" => {-16.7, -64.6},
    "PY" => {-23.4, -58.4},
    "CL" => {-35.7, -71.5},
    "AR" => {-38.4, -63.6},
    "UY" => {-32.5, -55.8},
    "IS" => {65.0, -18.5},
    "IE" => {53.4, -8.0},
    "GB" => {54.0, -2.0},
    "PT" => {39.5, -8.0},
    "ES" => {40.0, -3.7},
    "FR" => {46.6, 2.4},
    "BE" => {50.8, 4.5},
    "NL" => {52.3, 5.5},
    "LU" => {49.6, 6.1},
    "DE" => {51.2, 10.5},
    "CH" => {46.8, 8.2},
    "AT" => {47.5, 14.5},
    "IT" => {42.8, 12.8},
    "DK" => {56.0, 10.0},
    "NO" => {62.0, 10.0},
    "SE" => {62.0, 15.0},
    "FI" => {64.0, 26.0},
    "EE" => {58.6, 25.0},
    "LV" => {56.9, 24.6},
    "LT" => {55.2, 23.9},
    "PL" => {52.0, 19.1},
    "CZ" => {49.8, 15.5},
    "SK" => {48.7, 19.5},
    "HU" => {47.2, 19.5},
    "RO" => {45.9, 25.0},
    "BG" => {42.7, 25.5},
    "GR" => {39.0, 22.0},
    "AL" => {41.0, 20.0},
    "MK" => {41.6, 21.7},
    "RS" => {44.0, 21.0},
    "HR" => {45.1, 15.2},
    "SI" => {46.1, 14.8},
    "BA" => {44.2, 17.8},
    "ME" => {42.7, 19.4},
    "XK" => {42.6, 20.9},
    "UA" => {48.4, 31.2},
    "BY" => {53.5, 28.0},
    "MD" => {47.4, 28.4},
    "RU" => {61.5, 96.0},
    "CY" => {35.0, 33.0},
    "MT" => {35.9, 14.4},
    "LI" => {47.2, 9.5},
    "MC" => {43.7, 7.4},
    "AD" => {42.5, 1.5},
    "SM" => {43.9, 12.4},
    "VA" => {41.9, 12.45},
    "TR" => {39.0, 35.0},
    "GE" => {42.2, 43.5},
    "AM" => {40.1, 45.0},
    "AZ" => {40.4, 47.6},
    "IL" => {31.5, 34.8},
    "PS" => {31.9, 35.2},
    "JO" => {31.0, 36.0},
    "LB" => {33.9, 35.9},
    "SY" => {35.0, 38.5},
    "IQ" => {33.0, 44.0},
    "IR" => {32.0, 53.0},
    "SA" => {24.0, 45.0},
    "YE" => {15.5, 47.5},
    "OM" => {21.0, 57.0},
    "AE" => {24.0, 54.0},
    "QA" => {25.3, 51.2},
    "BH" => {26.0, 50.5},
    "KW" => {29.3, 47.5},
    "AF" => {33.0, 66.0},
    "PK" => {30.0, 70.0},
    "IN" => {22.0, 79.0},
    "NP" => {28.0, 84.0},
    "BT" => {27.5, 90.4},
    "BD" => {24.0, 90.0},
    "LK" => {7.5, 80.7},
    "MV" => {3.2, 73.0},
    "CN" => {35.0, 105.0},
    "MN" => {46.9, 103.8},
    "KZ" => {48.0, 68.0},
    "UZ" => {41.4, 64.6},
    "TM" => {39.0, 59.6},
    "TJ" => {38.9, 71.0},
    "KG" => {41.2, 74.8},
    "KR" => {36.0, 127.8},
    "KP" => {40.0, 127.0},
    "JP" => {36.0, 138.0},
    "TW" => {23.7, 121.0},
    "HK" => {22.3, 114.2},
    "MO" => {22.2, 113.5},
    "VN" => {16.0, 106.0},
    "LA" => {18.0, 105.5},
    "KH" => {12.6, 105.0},
    "TH" => {15.0, 101.0},
    "MM" => {22.0, 96.0},
    "MY" => {3.5, 109.0},
    "SG" => {1.35, 103.8},
    "ID" => {-2.0, 118.0},
    "PH" => {13.0, 122.0},
    "BN" => {4.5, 114.7},
    "TL" => {-8.8, 125.7},
    "EG" => {27.0, 30.0},
    "LY" => {27.0, 17.0},
    "TN" => {34.0, 9.0},
    "DZ" => {28.0, 3.0},
    "MA" => {32.0, -6.0},
    "EH" => {24.5, -13.0},
    "MR" => {20.0, -10.5},
    "ML" => {17.0, -4.0},
    "NE" => {17.6, 8.0},
    "TD" => {15.0, 19.0},
    "SD" => {15.5, 30.0},
    "SS" => {7.0, 30.0},
    "ER" => {15.3, 39.0},
    "DJ" => {11.6, 42.6},
    "ET" => {9.1, 40.0},
    "SO" => {5.2, 46.0},
    "KE" => {0.5, 37.9},
    "UG" => {1.3, 32.3},
    "RW" => {-2.0, 30.0},
    "BI" => {-3.4, 29.9},
    "TZ" => {-6.4, 34.9},
    "MZ" => {-18.7, 35.5},
    "MW" => {-13.5, 34.0},
    "ZM" => {-13.1, 27.8},
    "ZW" => {-19.0, 29.8},
    "BW" => {-22.3, 24.7},
    "NA" => {-22.6, 17.1},
    "ZA" => {-29.0, 24.0},
    "LS" => {-29.6, 28.2},
    "SZ" => {-26.5, 31.5},
    "AO" => {-11.2, 17.9},
    "CD" => {-2.9, 23.6},
    "CG" => {-0.2, 15.8},
    "GA" => {-0.6, 11.6},
    "GQ" => {1.6, 10.3},
    "CM" => {5.7, 12.7},
    "CF" => {6.6, 20.9},
    "NG" => {9.1, 8.7},
    "BJ" => {9.3, 2.3},
    "TG" => {8.6, 0.9},
    "GH" => {7.9, -1.2},
    "CI" => {7.5, -5.5},
    "LR" => {6.4, -9.4},
    "SL" => {8.5, -11.8},
    "GN" => {10.4, -10.9},
    "GW" => {12.0, -15.0},
    "SN" => {14.5, -14.5},
    "GM" => {13.4, -15.5},
    "CV" => {16.0, -24.0},
    "BF" => {12.2, -1.6},
    "AU" => {-25.3, 133.8},
    "NZ" => {-41.0, 174.0},
    "PG" => {-6.3, 143.9},
    "FJ" => {-17.7, 178.0},
    "SB" => {-9.6, 160.0},
    "VU" => {-16.0, 167.5},
    "NC" => {-21.0, 165.5},
    "PF" => {-17.7, -149.4},
    "WS" => {-13.8, -172.0},
    "TO" => {-21.2, -175.2}
  }

  # Viewbox for the "Where in the world" map, and the latitude band it
  # covers (clipped well short of the poles -- rather than the full
  # -90..90, which would spend a third of the map on empty Antarctic/Arctic
  # space no visitor centroid ever lands in).
  @map_width 720
  @map_height 360
  @map_lat_max 83
  @map_lat_min -58

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
  #
  # The payload key is "filter-value", not "value": LiveView's JS client
  # auto-adds a `value` key to every click payload from the element's native
  # DOM `.value` property when one exists (extractMeta in phoenix_live_view.js),
  # and <button> elements always have one (default ""). A `phx-value-value`
  # attribute here would get silently clobbered back to "" by that on every
  # real click -- Phoenix.LiveViewTest's render_click doesn't replicate that
  # DOM behavior, so a test asserting on `phx-value-value` would pass while
  # this was broken in every real browser.
  def handle_event("set_filter", %{"field" => field, "filter-value" => value}, socket) do
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

  # How wide a trend bucket should be per range: fine enough to be
  # informative, coarse enough that "all" (spanning years) doesn't render
  # thousands of hairline bars.
  defp trend_bucket_for("24h"), do: :hour
  defp trend_bucket_for("all"), do: :month
  defp trend_bucket_for(_range), do: :day

  defp load_report(socket) do
    {from, to} = range_bounds(socket.assigns.range)

    opts =
      [
        # Higher than Blog.Analytics's own default of 20: with click-to-filter
        # now inviting more distinct paths/countries/referrers into view, a
        # tighter cap made rows quietly disappear off the bottom of the list.
        limit: 50,
        trend_bucket: trend_bucket_for(socket.assigns.range),
        path: blank_to_nil(socket.assigns.path_filter),
        country: blank_to_nil(socket.assigns.country_filter)
      ] ++ referrer_opts(socket.assigns.referrer_filter)

    socket =
      case Analytics.stats(from, to, opts) do
        {:ok, report} ->
          assign(socket,
            summary: report.summary,
            trend: report.trend,
            top_paths: report.top_paths,
            top_countries: report.top_countries,
            top_referrers: report.top_referrers
          )

        {:error, _reason} ->
          assign(socket,
            summary: %{views: 0, sessions: 0, avg_duration_seconds: nil},
            trend: [],
            top_paths: [],
            top_countries: [],
            top_referrers: []
          )
      end

    case Analytics.kudos_summary(from, to) do
      {:ok, kudos} -> assign(socket, kudos_total: kudos.total, kudos_by_path: kudos.by_path)
      {:error, _reason} -> assign(socket, kudos_total: 0, kudos_by_path: [])
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

  # The largest value of `key` across `list`, or 0 for an empty list --
  # shared by the trend chart and the top-N lists to turn a raw count into a
  # 0-100 bar width/height without every callsite guarding against div by 0.
  defp max_of([], _key), do: 0
  defp max_of(list, key), do: list |> Enum.map(&Map.fetch!(&1, key)) |> Enum.max()

  defp bar_pct(_value, max) when max <= 0, do: 0
  defp bar_pct(value, max), do: value / max * 100

  # Same as bar_pct/2, but a bucket with at least one view always renders a
  # sliver -- at trend-chart height, a literal 0-100% scale would make small
  # non-zero buckets next to a tall spike disappear entirely.
  defp trend_bar_pct(0, _max), do: 0
  defp trend_bar_pct(_views, max) when max <= 0, do: 0
  defp trend_bar_pct(views, max), do: max(views / max * 100, 6)

  # Rows past this point in a top-N list are still counted in the stats
  # above, just not rendered -- Blog.Analytics is asked for at most this
  # many per breakdown (see load_report/1), so hitting it exactly means more
  # exist but got cut off.
  @list_limit 50

  defp truncated?(list), do: length(list) == @list_limit
  defp list_limit, do: @list_limit

  @month_abbr ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  defp trend_label(at, range)

  defp trend_label(%DateTime{} = at, "24h") do
    hour12 =
      case rem(at.hour, 12) do
        0 -> 12
        h -> h
      end

    "#{hour12}#{if at.hour < 12, do: "am", else: "pm"}"
  end

  defp trend_label(%DateTime{} = at, "all"),
    do: "#{Enum.at(@month_abbr, at.month - 1)} #{at.year}"

  defp trend_label(%DateTime{} = at, _range),
    do: "#{Enum.at(@month_abbr, at.month - 1)} #{at.day}"

  defp trend_tooltip(%{at: at, views: views}, range) do
    noun = if views == 1, do: "view", else: "views"
    "#{trend_label(at, range)} — #{views} #{noun}"
  end

  defp map_width, do: @map_width
  defp map_height, do: @map_height

  # Plain equirectangular projection (lat/lon -> SVG x/y), clipped to
  # @map_lat_min/@map_lat_max -- see that attribute for why.
  defp project(lat, lon) do
    x = (lon + 180) / 360 * @map_width
    y = (@map_lat_max - lat) / (@map_lat_max - @map_lat_min) * @map_height
    {x, y}
  end

  defp meridian_x(lon), do: elem(project(0, lon), 0)
  defp parallel_y(lat), do: elem(project(lat, 0), 1)

  # Every row in `top_countries` with a resolvable centroid, projected to
  # map coordinates. Rows for codes not in @country_centroids (or the
  # "Unknown" bucket) are dropped -- there's nowhere on the map to put them.
  defp mapped_countries(top_countries) do
    Enum.flat_map(top_countries, fn row ->
      case @country_centroids[row.country] do
        {lat, lon} ->
          {x, y} = project(lat, lon)
          [%{row: row, x: x, y: y}]

        nil ->
          []
      end
    end)
  end

  @bubble_min_radius 3
  @bubble_max_radius 20

  defp bubble_radius(_sessions, max) when max <= 0, do: @bubble_min_radius

  # Area-, not radius-, proportional: scaling the radius linearly with the
  # session count would make a bubble with 4x the sessions look 4x wider
  # (16x the *area*, which is what the eye actually compares two circles
  # by), badly overstating the difference.
  defp bubble_radius(sessions, max) do
    @bubble_min_radius + (@bubble_max_radius - @bubble_min_radius) * :math.sqrt(sessions / max)
  end

  defp bubble_opacity(_sessions, max) when max <= 0, do: 0.4
  defp bubble_opacity(sessions, max), do: 0.35 + 0.55 * (sessions / max)

  defp bubble_tooltip(%{country: country, sessions: sessions}) do
    noun = if sessions == 1, do: "session", else: "sessions"
    "#{country} — #{sessions} #{noun}"
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

        <div class="mb-10 grid grid-cols-2 gap-4 border-y border-ink py-6 text-center sm:grid-cols-4">
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
          <div>
            <div class="mark font-display text-[28px] font-bold text-ink">{@kudos_total}</div>
            <div class="label mt-1">Kudos</div>
          </div>
        </div>

        <section class="mb-10">
          <h2 class="label mb-3">Views over time</h2>
          <div :if={@trend == []} class="text-[13px] text-ink-3">No page views yet.</div>
          <div :if={@trend != []}>
            <div class="flex h-20 items-end gap-px border-b border-ink">
              <div
                :for={point <- @trend}
                class="min-w-px flex-1 bg-lime transition-colors hover:bg-ink"
                style={"height: #{trend_bar_pct(point.views, max_of(@trend, :views))}%"}
                title={trend_tooltip(point, @range)}
              >
              </div>
            </div>
            <div class="mt-1.5 flex justify-between text-[11px] text-ink-3">
              <span>{trend_label(hd(@trend).at, @range)}</span>
              <span>{trend_label(List.last(@trend).at, @range)}</span>
            </div>
          </div>
        </section>

        <section class="mb-10">
          <h2 class="label mb-3">Where in the world</h2>
          <% mapped = mapped_countries(@top_countries) %>
          <div :if={mapped == []} class="text-[13px] text-ink-3">No page views yet.</div>
          <svg
            :if={mapped != []}
            viewBox={"0 0 #{map_width()} #{map_height()}"}
            class="w-full border border-ink"
            role="img"
            aria-label="Sessions by country"
          >
            <line
              :for={lon <- -180..180//30}
              x1={meridian_x(lon)}
              y1="0"
              x2={meridian_x(lon)}
              y2={map_height()}
              stroke="var(--color-rule)"
            />
            <line
              :for={lat <- -40..80//20}
              x1="0"
              y1={parallel_y(lat)}
              x2={map_width()}
              y2={parallel_y(lat)}
              stroke="var(--color-rule)"
            />
            <circle
              :for={m <- mapped}
              cx={m.x}
              cy={m.y}
              r={bubble_radius(m.row.sessions, max_of(@top_countries, :sessions))}
              class={[
                "cursor-pointer fill-lime transition-opacity hover:opacity-100",
                @country_filter == m.row.country && "stroke-ink"
              ]}
              stroke-width="1.5"
              style={"opacity: #{bubble_opacity(m.row.sessions, max_of(@top_countries, :sessions))}"}
              phx-click="set_filter"
              phx-value-field="country"
              phx-value-filter-value={m.row.country}
            >
              <title>{bubble_tooltip(m.row)}</title>
            </circle>
          </svg>
        </section>

        <div class="grid gap-10 sm:grid-cols-2">
          <section>
            <h2 class="label mb-3">Top pages</h2>
            <div :if={@top_paths == []} class="text-[13px] text-ink-3">No page views yet.</div>
            <div class="max-h-[380px] divide-y divide-rule overflow-y-auto border-t border-ink">
              <button
                :for={row <- @top_paths}
                type="button"
                phx-click="set_filter"
                phx-value-field="path"
                phx-value-filter-value={row.path}
                class={[
                  "relative flex w-full items-center justify-between gap-4 py-2.5 text-left hover:bg-paper-2",
                  @path_filter == row.path && "bg-paper-2"
                ]}
              >
                <span
                  class="absolute inset-y-0 left-0 z-0 bar-fill"
                  style={"width: #{bar_pct(row.views, max_of(@top_paths, :views))}%"}
                ></span>
                <span class="relative z-10 truncate text-[13px] text-ink">{row.path}</span>
                <span class="relative z-10 shrink-0 text-[13px] text-ink-2">
                  {row.views} views &middot; {row.sessions} sessions &middot; {format_duration(
                    row.avg_duration_seconds
                  )}
                </span>
              </button>
            </div>
            <div :if={truncated?(@top_paths)} class="mt-2 text-[11.5px] text-ink-3">
              Showing the top {list_limit()}. Narrow the filters above to see more.
            </div>
          </section>

          <section>
            <h2 class="label mb-3">Top countries</h2>
            <div :if={@top_countries == []} class="text-[13px] text-ink-3">No page views yet.</div>
            <div class="max-h-[380px] divide-y divide-rule overflow-y-auto border-t border-ink">
              <button
                :for={row <- @top_countries}
                type="button"
                phx-click="set_filter"
                phx-value-field="country"
                phx-value-filter-value={row.country}
                class={[
                  "relative flex w-full items-center justify-between gap-4 py-2.5 text-left hover:bg-paper-2",
                  @country_filter == row.country && "bg-paper-2"
                ]}
              >
                <span
                  class="absolute inset-y-0 left-0 z-0 bar-fill"
                  style={"width: #{bar_pct(row.sessions, max_of(@top_countries, :sessions))}%"}
                ></span>
                <span class="relative z-10 text-[13px] text-ink">
                  {flag(row.country)} {row.country}
                </span>
                <span class="relative z-10 shrink-0 text-[13px] text-ink-2">
                  {row.sessions} sessions
                </span>
              </button>
            </div>
            <div :if={truncated?(@top_countries)} class="mt-2 text-[11.5px] text-ink-3">
              Showing the top {list_limit()}. Narrow the filters above to see more.
            </div>
          </section>

          <section class="sm:col-span-2">
            <h2 class="label mb-3">Kudos by page</h2>
            <div :if={@kudos_by_path == []} class="text-[13px] text-ink-3">No kudos yet.</div>
            <div class="max-h-[380px] divide-y divide-rule overflow-y-auto border-t border-ink">
              <button
                :for={row <- @kudos_by_path}
                type="button"
                phx-click="set_filter"
                phx-value-field="path"
                phx-value-filter-value={row.path}
                class={[
                  "relative flex w-full items-center justify-between gap-4 py-2.5 text-left hover:bg-paper-2",
                  @path_filter == row.path && "bg-paper-2"
                ]}
              >
                <span
                  class="absolute inset-y-0 left-0 z-0 bar-fill"
                  style={"width: #{bar_pct(row.count, max_of(@kudos_by_path, :count))}%"}
                ></span>
                <span class="relative z-10 truncate text-[13px] text-ink">{row.path}</span>
                <span class="relative z-10 shrink-0 text-[13px] text-ink-2">
                  {row.count} kudos
                </span>
              </button>
            </div>
          </section>

          <section class="sm:col-span-2">
            <h2 class="label mb-3">Top referrers</h2>
            <div :if={@top_referrers == []} class="text-[13px] text-ink-3">No page views yet.</div>
            <div class="max-h-[380px] divide-y divide-rule overflow-y-auto border-t border-ink">
              <button
                :for={row <- @top_referrers}
                type="button"
                phx-click="set_filter"
                phx-value-field="referrer"
                phx-value-filter-value={referrer_filter_value(row.source)}
                class={[
                  "relative flex w-full items-center justify-between gap-4 py-2.5 text-left hover:bg-paper-2",
                  @referrer_filter == referrer_filter_value(row.source) && "bg-paper-2"
                ]}
              >
                <span
                  class="absolute inset-y-0 left-0 z-0 bar-fill"
                  style={"width: #{bar_pct(row.sessions, max_of(@top_referrers, :sessions))}%"}
                ></span>
                <span class="relative z-10 text-[13px] text-ink">{row.source}</span>
                <span class="relative z-10 shrink-0 text-[13px] text-ink-2">
                  {row.sessions} sessions
                </span>
              </button>
            </div>
            <div :if={truncated?(@top_referrers)} class="mt-2 text-[11.5px] text-ink-3">
              Showing the top {list_limit()}. Narrow the filters above to see more.
            </div>
          </section>
        </div>
      </div>
    </.page_body>
    """
  end
end
