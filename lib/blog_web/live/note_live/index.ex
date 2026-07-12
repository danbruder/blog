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
    <.page_hero title="Notes" subtitle="Small learnings and TILs — quicker and rougher than the blog." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <div :for={note <- @notes} class="mb-4 flex items-baseline gap-3">
          <h2 class="text-lg text-[color:var(--accent-heading)]">
            <.link navigate={~p"/notes/#{note.slug}"}>{note.title}</.link>
          </h2>
          <time
            :if={note.published_at}
            datetime={Date.to_iso8601(note.published_at)}
            class="text-sm text-zinc-400 shrink-0"
          >
            {Calendar.strftime(note.published_at, "%B %-d, %Y")}
          </time>
        </div>
      </div>
    </div>
    """
  end
end
