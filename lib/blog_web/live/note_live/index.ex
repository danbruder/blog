defmodule BlogWeb.NoteLive.Index do
  use BlogWeb, :live_view

  alias Blog.Content

  @impl true
  def mount(_params, _session, socket) do
    notes = Content.list_published_notes()
    {:ok, assign(socket, notes: notes, page_title: "Notes | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero
      eyebrow="Notes"
      title="The lab notebook."
      subtitle="Small learnings and TILs — quicker and rougher than the blog. The things I looked up once and refused to look up twice."
    />

    <.page_body class="pt-0">
      <.link
        :for={note <- @notes}
        navigate={~p"/notes/#{note.slug}"}
        class="grid grid-cols-[84px_minmax(0,1fr)] items-baseline gap-4 border-b border-rule py-[13px] !shadow-none hover:!bg-transparent sm:grid-cols-[92px_minmax(0,1fr)_110px] sm:gap-5"
      >
        <time
          :if={note.published_at}
          datetime={Date.to_iso8601(note.published_at)}
          class="text-[11.5px] tracking-[0.04em] text-ink-3"
        >
          {Calendar.strftime(note.published_at, "%b %-d %Y")}
        </time>
        <span :if={is_nil(note.published_at)} class="text-[11.5px] text-ink-3"></span>
        <span class="text-[15.5px] leading-[1.4] text-ink hover:bg-lime hover:text-on-lime">
          {note.title}
        </span>
        <span
          :if={tag_of(note)}
          class="hidden text-right text-[10.5px] font-semibold uppercase tracking-[0.1em] text-ink-3 sm:block"
        >
          {tag_of(note)}
        </span>
      </.link>

      <p class="pt-6 text-[13px] text-ink-3">
        {length(@notes)} {if length(@notes) == 1, do: "note", else: "notes"}
      </p>
    </.page_body>
    """
  end

  defp tag_of(%{category: cat}) when is_binary(cat) and cat != "", do: cat

  defp tag_of(%{tags: tags}) when is_binary(tags) and tags != "" do
    tags |> String.split(",", trim: true) |> List.first() |> String.trim()
  end

  defp tag_of(_), do: nil
end
