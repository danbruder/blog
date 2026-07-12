# Home Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make `/` a Home landing (intro hero + scrollable per-subsection bands); move the posts list to `/writing`; add a Home link to the sidebar.

**Architecture:** Repurpose `HomeLive` (at `/`) into the landing; extract the old posts-list render into a new `WritingLive` at `/writing`. Sidebar gains Home and points Writing at `/writing`.

**Tech Stack:** Elixir, Phoenix LiveView, Tailwind.

---

## Task H1: WritingLive at /writing (posts list moved)

**Files:** Create `lib/blog_web/live/writing_live.ex`, `test/blog_web/live/writing_live_test.exs`; Modify `lib/blog_web/router.ex`.

- [ ] **Step 1:** Create `lib/blog_web/live/writing_live.ex` — the current `HomeLive` posts-list render, renamed:

```elixir
defmodule BlogWeb.WritingLive do
  use BlogWeb, :live_view

  alias Blog.Content

  @impl true
  def mount(_params, _session, socket) do
    posts = Content.list_published_posts()
    {:ok, assign(socket, posts: posts, page_title: "Writing | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero title="Writing" subtitle="Essays on software, management, and building things." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <h4 class="text-lg md:text-xl text-gray-500">Latest Posts</h4>
        <div :for={post <- @posts} class="mb-6">
          <h2 class="text-xl md:text-3xl text-[color:var(--accent-heading)]">
            <.link navigate={~p"/blog/#{post.slug}"}>{post.title}</.link>
          </h2>
          <time :if={post.published_at} datetime={Date.to_iso8601(post.published_at)} class="text-zinc-400">
            {Calendar.strftime(post.published_at, "%B %-d, %Y")}
          </time>
        </div>

        <p class="mt-8 text-sm text-zinc-400">
          Looking for smaller learnings and TILs?
          <.link class="link" navigate={~p"/notes"}>Check out the notes</.link>.
        </p>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 2:** Add route in `lib/blog_web/router.ex` inside `live_session :public`, after the `/` line:

```elixir
      live("/writing", WritingLive, :index)
```

- [ ] **Step 3:** Create `test/blog_web/live/writing_live_test.exs`:

```elixir
defmodule BlogWeb.WritingLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Blog.Content

  test "lists published posts, not notes", %{conn: conn} do
    {:ok, _} = Content.create_post(%{title: "A Post", slug: "a-post", body: "x", kind: "post", published: true, published_at: ~D[2024-01-01]})
    {:ok, _} = Content.create_post(%{title: "A Note", slug: "a-note", body: "x", kind: "note", published: true, published_at: ~D[2024-01-01]})
    {:ok, _view, html} = live(conn, ~p"/writing")
    assert html =~ "A Post"
    refute html =~ "A Note"
  end
end
```

- [ ] **Step 4:** `mix test test/blog_web/live/writing_live_test.exs` → PASS.
- [ ] **Step 5:** Commit.

---

## Task H2: HomeLive becomes the landing

**Files:** Modify `lib/blog_web/live/home_live.ex`, `test/blog_web/live/home_live_test.exs`.

- [ ] **Step 1:** Replace `lib/blog_web/live/home_live.ex` entirely:

```elixir
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
```

- [ ] **Step 2:** Replace assertions in `test/blog_web/live/home_live_test.exs` so the whole test reads:

```elixir
defmodule BlogWeb.HomeLiveTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Blog.Content

  test "renders the landing with a band per subsection", %{conn: conn} do
    {:ok, _post} =
      Content.create_post(%{title: "My First Post", slug: "my-first-post", body: "hello", kind: "post", published: true, published_at: ~D[2024-01-01]})

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Hi, I&#39;m Dan"
    assert html =~ "Writing"
    assert html =~ "Notes"
    assert html =~ "Games"
    assert html =~ "Podcasts"
    assert html =~ "Projects"
    assert html =~ ~s(href="/writing")
    assert html =~ "My First Post"
  end
end
```

- [ ] **Step 3:** `mix test test/blog_web/live/home_live_test.exs` → PASS.
- [ ] **Step 4:** Commit.

---

## Task H3: Sidebar Home link + active logic

**Files:** Modify `lib/blog_web/components/layouts/app.html.heex`.

- [ ] **Step 1:** Change `nav_items` to prepend Home and repoint Writing:

```heex
<% nav_items = [
  {"Home", ~p"/", "🏠"},
  {"Writing", ~p"/writing", "✍️"},
  {"Notes", ~p"/notes", "🗒️"},
  {"Games", ~p"/games", "🎮"},
  {"Podcasts", ~p"/podcasts", "🎙️"},
  {"Projects", ~p"/projects", "🚧"}
] %>
```

- [ ] **Step 2:** Replace the `active?` helper so Home matches only `/` and Writing owns `/writing` + `/blog`:

```heex
<% active? = fn href ->
  cond do
    href == "/" -> current == "/"
    href == "/writing" -> current == "/writing" or String.starts_with?(current, "/blog")
    true -> current == href or String.starts_with?(current, href <> "/")
  end
end %>
```

- [ ] **Step 3:** `mix compile --warnings-as-errors` → clean; manual check active states on `/`, `/writing`, a post.
- [ ] **Step 4:** Commit.

---

## Self-Review Notes
- Covers: `/` landing (H2), `/writing` posts list (H1), sidebar Home + active logic (H3).
- `HomeLive` no longer lists all posts (moved to `WritingLive`); it loads only latest post/note for the bands.
- Active logic: Home exact `/`; Writing `/writing`+`/blog`; others nested-safe.
```
