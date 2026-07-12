defmodule BlogWeb.HomeLive do
  use BlogWeb, :live_view

  alias Blog.Content

  @impl true
  def mount(_params, _session, socket) do
    latest_post = Content.list_published_posts() |> List.first()
    latest_note = Content.list_published_notes() |> List.first()

    {:ok,
     assign(socket,
       page_title: "Dan Bruder | Engineering Director",
       latest_post: latest_post,
       latest_note: latest_note
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero
      title="Hi, I'm Dan"
      subtitle="Engineering director making reality capture easy — here's what's around."
    />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-3xl divide-y divide-zinc-800">
        <section class="py-10">
          <h2 class="text-2xl text-[color:var(--accent-heading)]">✍️ Writing</h2>
          <p class="mt-2 text-zinc-300">Essays on software, management, and building teams.</p>
          <p :if={@latest_post} class="mt-1 text-sm text-zinc-500">
            Latest: {@latest_post.title}
          </p>
          <.link navigate={~p"/writing"} class="link inline-block mt-3">Read the blog →</.link>
        </section>

        <section class="py-10">
          <h2 class="text-2xl text-[color:var(--accent-heading)]">🗒️ Notes</h2>
          <p class="mt-2 text-zinc-300">Small learnings and TILs — quicker and rougher than the blog.</p>
          <p :if={@latest_note} class="mt-1 text-sm text-zinc-500">
            Latest: {@latest_note.title}
          </p>
          <.link navigate={~p"/notes"} class="link inline-block mt-3">Browse notes →</.link>
        </section>

        <section class="py-10">
          <h2 class="text-2xl text-[color:var(--accent-heading)]">🎮 Games</h2>
          <p class="mt-2 text-zinc-300">Multiplayer toys — a shared Snake and a falling-sand sandbox everyone paints into together.</p>
          <.link navigate={~p"/games"} class="link inline-block mt-3">Play →</.link>
        </section>

        <section class="py-10">
          <h2 class="text-2xl text-[color:var(--accent-heading)]">🎙️ Podcasts</h2>
          <p class="mt-2 text-zinc-300">Shows I've been a guest on.</p>
          <.link navigate={~p"/podcasts"} class="link inline-block mt-3">Listen →</.link>
        </section>

        <section class="py-10">
          <h2 class="text-2xl text-[color:var(--accent-heading)]">🚧 Projects</h2>
          <p class="mt-2 text-zinc-300">Things I'm building. Coming soon.</p>
          <.link navigate={~p"/projects"} class="link inline-block mt-3">Take a look →</.link>
        </section>
      </div>
    </div>
    """
  end
end
