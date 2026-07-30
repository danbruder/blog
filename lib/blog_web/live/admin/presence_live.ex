defmodule BlogWeb.Admin.PresenceLive do
  use BlogWeb, :live_view

  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blog.PubSub, PresenceTracker.topic())
    end

    {:ok, assign(socket, page_title: "Viewers", pages: pages_by_count())}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, pages: pages_by_count())}
  end

  defp pages_by_count do
    PresenceTracker.topic() |> Presence.list() |> summarize()
  end

  @doc """
  Groups live presences by the page they're on, then by country within each
  page. Pages and countries are both sorted by headcount, descending.
  """
  def summarize(presences) do
    presences
    |> Enum.map(fn {_key, %{metas: [meta | _]}} ->
      {meta.path || "Unknown", meta.country || "Unknown"}
    end)
    |> Enum.group_by(fn {path, _country} -> path end, fn {_path, country} -> country end)
    |> Enum.map(fn {path, countries} ->
      %{path: path, count: length(countries), countries: by_count(countries)}
    end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  defp by_count(countries) do
    countries
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_country, count} -> -count end)
  end

  @doc false
  def flag(<<a, b>>) when a in ?A..?Z and b in ?A..?Z do
    <<a + 0x1F1A5::utf8, b + 0x1F1A5::utf8>>
  end

  def flag(_), do: "🏳️"

  defp total(pages), do: Enum.reduce(pages, 0, &(&1.count + &2))

  defp pluralize(1, word), do: word
  defp pluralize(_count, word), do: word <> "s"

  @impl true
  def render(assigns) do
    ~H"""
    <.page_body>
      <div class="mx-auto max-w-3xl">
        <div class="mb-8 flex items-center justify-between gap-4">
          <h1 class="font-display text-[28px] font-bold tracking-[-0.03em] text-ink">Viewers</h1>
          <div class="flex items-center gap-4">
            <.link
              navigate={~p"/admin"}
              class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
            >
              Posts
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

        <div class="mb-8 flex items-center gap-2 text-[13px] text-ink-2">
          <span class="inline-block h-2 w-2 bg-lime"></span>
          <span class="mark font-semibold">{total(@pages)}</span>
          reading right now across {length(@pages)} {pluralize(length(@pages), "page")}
        </div>

        <div :if={@pages == []} class="text-[15px] text-ink-3">Nobody's here right now.</div>

        <div class="divide-y divide-rule border-t border-ink">
          <div :for={page <- @pages} class="py-4">
            <div class="flex items-baseline justify-between gap-4">
              <span class="text-[15px] text-ink">{page.path}</span>
              <span class="label shrink-0">
                {page.count} {pluralize(page.count, "viewer")}
              </span>
            </div>

            <div class="mt-2.5 flex flex-wrap gap-x-4 gap-y-1.5">
              <span
                :for={{country, count} <- page.countries}
                class="flex items-center gap-1.5 text-[13px] text-ink-2"
              >
                <span class="text-base leading-none">{flag(country)}</span>
                {country}
                <span class="text-ink-3">{count}</span>
              </span>
            </div>
          </div>
        </div>
      </div>
    </.page_body>
    """
  end
end
