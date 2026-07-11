defmodule BlogWeb.Admin.PresenceLive do
  use BlogWeb, :live_view

  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blog.PubSub, PresenceTracker.topic())
    end

    {:ok, assign(socket, page_title: "Viewers", countries: countries_by_count())}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, countries: countries_by_count())}
  end

  defp countries_by_count do
    PresenceTracker.topic() |> Presence.list() |> summarize()
  end

  @doc false
  def summarize(presences) do
    presences
    |> Enum.map(fn {_key, %{metas: [meta | _]}} -> meta.country || "Unknown" end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_country, count} -> -count end)
  end

  @doc false
  def flag(<<a, b>>) when a in ?A..?Z and b in ?A..?Z do
    <<a + 0x1F1A5::utf8, b + 0x1F1A5::utf8>>
  end

  def flag(_), do: "🏳️"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-3xl">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-3xl text-sky-200">Viewers</h1>
          <div class="flex items-center gap-3">
            <.link navigate={~p"/admin"} class="text-sm text-zinc-400 underline">Posts</.link>
            <.link href={~p"/admin/logout"} method="delete" class="text-sm text-zinc-400 underline">
              Log out
            </.link>
          </div>
        </div>

        <p class="text-zinc-500 mb-6">
          {Enum.reduce(@countries, 0, fn {_country, count}, total -> total + count end)} live right now
        </p>

        <div :if={@countries == []} class="text-zinc-500">Nobody's here right now.</div>

        <div class="divide-y divide-zinc-800">
          <div
            :for={{country, count} <- @countries}
            class="py-3 flex items-center justify-between gap-4"
          >
            <div class="flex items-center gap-3">
              <span class="text-2xl">{flag(country)}</span>
              <span class="text-sky-100">{country}</span>
            </div>
            <span class="text-zinc-500">{count}</span>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
