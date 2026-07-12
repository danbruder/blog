# Sidebar Layout + Painted Heros Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the blog to a persistent left-sidebar layout, confine the CSS paint-worklet shapes to hero bands (flat grey elsewhere), and add Games (landing → nested Snake), Podcasts, and Projects pages.

**Architecture:** The app layout (`app.html.heex`) becomes a flex row: a persistent sidebar (identity + nav) plus a content column. A new `<.page_hero>` function component carries the `.painted` background and the page/post title; every page renders it above flat-grey body content. New LiveViews are added for Games, Podcasts, Projects; Snake moves under `/games/snake` with a 301 redirect from `/snake`.

**Tech Stack:** Elixir, Phoenix LiveView, Tailwind CSS, CSS Houdini Paint Worklet, SQLite (Ecto).

---

## File Structure

**New files:**
- `lib/blog_web/live/games_live/index.ex` — Games landing (grid of game cards).
- `lib/blog_web/live/podcast_live/index.ex` — Podcasts "appearances".
- `lib/blog_web/live/project_live/index.ex` — Projects "coming soon".
- `lib/blog_web/controllers/redirect_controller.ex` — 301 `/snake` → `/games/snake`.
- `test/blog_web/live/games_live_index_test.exs`
- `test/blog_web/live/podcast_live_index_test.exs`
- `test/blog_web/live/project_live_index_test.exs`
- `test/blog_web/controllers/redirect_controller_test.exs`

**Modified files:**
- `lib/blog_web/components/core_components.ex` — add `<.page_hero>`.
- `lib/blog_web/components/layouts/app.html.heex` — sidebar + mobile bar.
- `lib/blog_web/components/layouts/root.html.heex` — drop `painted` from `<body>`.
- `assets/css/app.css` — `.painted` scoped to hero (rule already targets the class; only the body usage moves).
- `assets/js/app.js` — register `MobileNav` hook.
- `lib/blog_web/router.ex` — new routes, moved Snake route, `/snake` redirect.
- `lib/blog_web/live/home_live.ex` — `page_hero`, drop "Hi I'm Dan".
- `lib/blog_web/live/note_live/index.ex` — `page_hero`.
- `lib/blog_web/live/post_live/show.ex` — `page_hero`; snake link → `/games/snake`.
- `lib/blog_web/live/snake_live.ex` — `page_hero`.
- `test/blog_web/live/home_live_test.exs` — update assertion.
- About post body in `blog_dev.db` — remove the Software Unscripted sentence.

---

## Task 1: `page_hero` component + move `.painted` off the body

**Files:**
- Modify: `lib/blog_web/components/core_components.ex` (add component at end, before final `end`)
- Modify: `lib/blog_web/components/layouts/root.html.heex:66` (body class)
- Modify: `assets/css/app.css` (hero base tone)

- [ ] **Step 1: Add the `page_hero` component**

Add this function component to `lib/blog_web/components/core_components.ex` (inside the module, e.g. just before the module's final `end`):

```elixir
  @doc """
  A hero band. The `.painted` class renders the dynamic paint-worklet shapes;
  this is the only element on the page that carries them. Title (and optional
  eyebrow / subtitle / extra slot) sit above the shapes.
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :eyebrow, :string, default: nil
  attr :title_class, :string, default: "text-3xl md:text-5xl"
  slot :inner_block

  def page_hero(assigns) do
    ~H"""
    <section class="painted relative overflow-hidden bg-zinc-950 border-b border-zinc-800">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-3xl relative z-10 py-12 md:py-16">
          <p :if={@eyebrow} class="font-fancy text-sm uppercase tracking-wide text-zinc-400">
            {@eyebrow}
          </p>
          <h1 class={["text-[color:var(--accent-heading)]", @title_class]}>{@title}</h1>
          <p :if={@subtitle} class="mt-2 text-stone-200">{@subtitle}</p>
          {render_slot(@inner_block)}
        </div>
      </div>
    </section>
    """
  end
```

- [ ] **Step 2: Remove `painted` from the body**

In `lib/blog_web/components/layouts/root.html.heex`, change the `<body>` tag:

```heex
  <body class="bg-zinc-900 text-zinc-50 flex flex-col min-h-screen">
```

(Removed the leading `painted` class; everything else unchanged.)

- [ ] **Step 3: Give the hero a base tone so shapes read**

In `assets/css/app.css`, the existing rule is:

```css
.painted {
  background-image: paint(myPaintedBackground);
}
```

Leave it as-is — the component already sets `bg-zinc-950` on the same element, and the paint worklet draws its subtle shapes over that. No CSS change is strictly required here; confirm the rule still exists and is unchanged.

- [ ] **Step 4: Compile to verify no errors**

Run: `mix compile --warnings-as-errors`
Expected: compiles cleanly (the component is defined but not yet used).

- [ ] **Step 5: Commit**

```bash
git add lib/blog_web/components/core_components.ex lib/blog_web/components/layouts/root.html.heex assets/css/app.css
git commit -m "Add page_hero component and scope painted shapes off the body"
```

---

## Task 2: Sidebar layout shell + mobile nav

**Files:**
- Modify: `lib/blog_web/components/layouts/app.html.heex` (full rewrite of header → sidebar)
- Modify: `assets/js/app.js` (add `MobileNav` hook)

- [ ] **Step 1: Rewrite `app.html.heex` with the sidebar shell**

Replace the entire contents of `lib/blog_web/components/layouts/app.html.heex` with:

```heex
<.flash_group flash={@flash} />

<% nav_items = [
  {"Writing", ~p"/", "✍️"},
  {"Notes", ~p"/notes", "🗒️"},
  {"Games", ~p"/games", "🎮"},
  {"Podcasts", ~p"/podcasts", "🎙️"},
  {"Projects", ~p"/projects", "🚧"}
] %>
<% current = assigns[:current_path] || "/" %>
<% active? = fn href -> href == current or (href != "/" and String.starts_with?(current, href)) end %>

<div class="flex min-h-screen flex-col md:flex-row">
  <%!-- Sidebar (desktop) / top bar (mobile) --%>
  <aside class="md:w-60 md:flex-shrink-0 md:border-r border-b md:border-b-0 border-zinc-800 bg-zinc-900">
    <div class="md:sticky md:top-0 flex flex-col md:h-screen p-6">
      <div class="flex items-center justify-between">
        <a href="/" class="flex items-center space-x-3">
          <img
            class="w-10 h-10 block rounded-full object-cover"
            src={~p"/images/my-face-new.jpg"}
            alt="Dan Bruder"
          />
          <span class="font-fancy text-lg">Dan Bruder</span>
        </a>
        <button
          id="mobile-nav-toggle"
          phx-hook="MobileNav"
          type="button"
          class="md:hidden !border-0 !shadow-none text-zinc-300 px-2"
          aria-label="Toggle navigation"
        >☰</button>
      </div>

      <p class="mt-4 text-sm text-zinc-400 hidden md:block">
        Engineering director making
        <a class="link" href="https://www.dronedeploy.com/">reality capture</a> easy.
      </p>

      <nav id="mobile-nav" class="hidden md:flex flex-col gap-1 mt-6">
        <.link
          :for={{label, href, emoji} <- nav_items}
          navigate={href}
          class={[
            "font-fancy px-3 py-2 rounded-lg no-underline",
            active?.(href) && "bg-zinc-800 text-[color:var(--accent-heading)]",
            !active?.(href) && "text-zinc-300 hover:bg-zinc-800/60"
          ]}
        >
          <span class="mr-2">{emoji}</span>{label}
        </.link>
      </nav>

      <div class="mt-auto pt-6 text-xs text-zinc-500 hidden md:flex flex-col gap-1">
        <a class="text-zinc-400 no-underline hover:text-zinc-200" href="/blog/about">👋 about me</a>
        <a class="text-zinc-400 no-underline hover:text-zinc-200" href={~p"/rss.xml"}>RSS</a>
        <a class="text-zinc-400 no-underline hover:text-zinc-200" href="https://github.com/danbruder">GitHub</a>
        <span class="mt-2">&copy; {Date.utc_today().year} Dan Bruder</span>
      </div>
    </div>
  </aside>

  <%!-- Content column --%>
  <main class="flex-1 min-w-0">
    {@inner_content}
  </main>
</div>

<div
  :if={assigns[:viewer_count]}
  class="fixed bottom-4 right-4 z-50 flex items-center gap-2 rounded-full bg-zinc-900/90 border border-zinc-700 px-3 py-1.5 text-sm text-zinc-300 shadow-lg backdrop-blur"
>
  <span class="relative flex h-2 w-2">
    <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-sky-400 opacity-75"></span>
    <span class="relative inline-flex h-2 w-2 rounded-full bg-sky-400"></span>
  </span>
  {@viewer_count} {if @viewer_count == 1, do: "viewer", else: "viewers"}
</div>
```

Notes: the `!border-0 !shadow-none` on the toggle overrides the global `button`
styling in `app.css`. On mobile the nav (`#mobile-nav`) starts `hidden` and the
`MobileNav` hook toggles it; on `md+` it is always `flex` via the responsive
`md:flex` class.

- [ ] **Step 2: Add the `MobileNav` hook**

In `assets/js/app.js`, add a hook to the `Hooks` object (after `DblClickEdit`):

```javascript
  // Toggles the mobile nav list open/closed on small screens.
  MobileNav: {
    mounted() {
      this.el.addEventListener("click", () => {
        const nav = document.getElementById("mobile-nav")
        if (nav) nav.classList.toggle("hidden")
      })
    }
  }
```

- [ ] **Step 3: Compile and boot the server**

Run: `mix compile --warnings-as-errors`
Expected: compiles cleanly.

- [ ] **Step 4: Manually verify the shell**

Run: `mix phx.server`, open `http://localhost:4000/`.
Expected: sidebar on the left with face, "Dan Bruder", bio, nav (Writing active),
about/RSS/GitHub/© at the bottom. Narrow the window below `md`: sidebar becomes a
top bar with a ☰ button that shows/hides the nav.

- [ ] **Step 5: Commit**

```bash
git add lib/blog_web/components/layouts/app.html.heex assets/js/app.js
git commit -m "Replace top header with persistent sidebar + mobile nav toggle"
```

---

## Task 3: HomeLive → "Writing" hero

**Files:**
- Modify: `lib/blog_web/live/home_live.ex`
- Test: `test/blog_web/live/home_live_test.exs`

- [ ] **Step 1: Update the failing test**

Replace the assertion block in `test/blog_web/live/home_live_test.exs` (the two
`assert html =~` lines) with:

```elixir
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "My First Post"
    assert html =~ "Writing"
    refute html =~ "Hi, I&#39;m Dan"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/blog_web/live/home_live_test.exs`
Expected: FAIL — current page still renders "Hi, I'm Dan" and no "Writing" hero.

- [ ] **Step 3: Update HomeLive render**

Replace the `render/1` function in `lib/blog_web/live/home_live.ex` with:

```elixir
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
          <time
            :if={post.published_at}
            datetime={Date.to_iso8601(post.published_at)}
            class="text-zinc-400"
          >
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/blog_web/live/home_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/blog_web/live/home_live.ex test/blog_web/live/home_live_test.exs
git commit -m "Home page becomes Writing with page_hero"
```

---

## Task 4: NoteLive.Index → hero

**Files:**
- Modify: `lib/blog_web/live/note_live/index.ex`
- Test: `test/blog_web/live/note_live_index_test.exs` (already passes; re-run)

- [ ] **Step 1: Update NoteLive render**

Replace the `render/1` in `lib/blog_web/live/note_live/index.ex` with:

```elixir
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
```

- [ ] **Step 2: Run the notes test**

Run: `mix test test/blog_web/live/note_live_index_test.exs`
Expected: PASS (asserts "My Note" present, "My Post" absent — still true).

- [ ] **Step 3: Commit**

```bash
git add lib/blog_web/live/note_live/index.ex
git commit -m "Notes index uses page_hero"
```

---

## Task 5: PostLive.Show → hero + snake link

**Files:**
- Modify: `lib/blog_web/live/post_live/show.ex`
- Test: `test/blog_web/live/post_live_show_test.exs` (re-run; still passes)

- [ ] **Step 1: Update PostLive.Show render**

In `lib/blog_web/live/post_live/show.ex`, replace the opening of `render/1` —
from `<div class="mx-auto max-w-7xl ...">` through the closing of the title/date
block — so the title/date move into the hero. Replace the full `render/1` with:

```elixir
  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero title={@post.title} title_class="text-3xl md:text-5xl">
      <span
        :if={@post.published_at}
        class="text-zinc-300 font-bold flex items-center space-x-3 mt-3"
      >
        <time datetime={Date.to_iso8601(@post.published_at)}>
          {Calendar.strftime(@post.published_at, "%B %-d, %Y")}
        </time>
      </span>
    </.page_hero>

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <div id="post-body" phx-hook="Highlight" phx-update="ignore" class="markdown-content">
          {Phoenix.HTML.raw(@body_html)}
        </div>

        <form
          :if={@post.kind == "post"}
          action="https://buttondown.email/api/emails/embed-subscribe/danbruder"
          method="post"
          target="popupwindow"
          onsubmit="window.open('https://buttondown.email/danbruder', 'popupwindow')"
          class="embeddable-buttondown-form bg-zinc-800 p-4 mt-24"
        >
          <label for="bd-email" class="block pb-2">Newsletter signup:</label>
          <input
            type="email"
            class="bg-zinc-700 text-zinc-100 rounded my-2"
            placeholder="email"
            name="email"
            id="bd-email"
          />
          <input
            type="submit"
            class="bg-sky-900 text-sky-400 p-2 rounded border border-sky-900 bg-opacity-50"
            value="Subscribe"
          />
        </form>

        <h3 :if={@post.kind == "post"} class="mt-12">
          Made it this far? Have a go at the game of
          <a class="underline" href={~p"/games/snake"}>snake</a>
        </h3>
      </div>
    </div>
    """
  end
```

(The only functional link change is `~p"/snake"` → `~p"/games/snake"`. This route
exists after Task 6; do Task 6 before compiling this. If executing strictly in
order, temporarily this `~p` will fail verified-routes compilation — see Task 6
note. To avoid a broken intermediate build, run Task 6 immediately after this
edit and compile once at the end of Task 6.)

- [ ] **Step 2: Commit (after Task 6 compiles cleanly)**

```bash
git add lib/blog_web/live/post_live/show.ex
git commit -m "Post/note show uses page_hero; snake link points to /games/snake"
```

---

## Task 6: Router — Snake move, redirect, new page routes

**Files:**
- Modify: `lib/blog_web/router.ex`
- Create: `lib/blog_web/controllers/redirect_controller.ex`
- Create: `test/blog_web/controllers/redirect_controller_test.exs`

This task references modules created in Tasks 7–10. Create those modules first
(or create empty stubs), then wire routes. Recommended order: do Tasks 7, 8, 9,
10 to create the LiveView modules, then return here to add routes. The plan lists
this task at 6 for grouping; **execute the module-creation tasks (7–10) before
compiling the router.**

- [ ] **Step 1: Create the redirect controller**

Create `lib/blog_web/controllers/redirect_controller.ex`:

```elixir
defmodule BlogWeb.RedirectController do
  @moduledoc """
  Static path redirects. `/snake` 301s to its new home under `/games/snake`.
  """
  use BlogWeb, :controller

  def snake(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: ~p"/games/snake")
    |> halt()
  end
end
```

- [ ] **Step 2: Update the router**

In `lib/blog_web/router.ex`, inside the `live_session :public` block, replace:

```elixir
      live("/snake", SnakeLive, :index)
```

with:

```elixir
      live("/games", GamesLive.Index, :index)
      live("/games/snake", SnakeLive, :index)
      live("/podcasts", PodcastLive.Index, :index)
      live("/projects", ProjectLive.Index, :index)
```

Then, still in the first `scope "/", BlogWeb do` block but **outside** the
`live_session` (e.g. just after the `live_session ... end`), add the redirect:

```elixir
    get("/snake", RedirectController, :snake)
```

- [ ] **Step 3: Write the redirect test**

Create `test/blog_web/controllers/redirect_controller_test.exs`:

```elixir
defmodule BlogWeb.RedirectControllerTest do
  use BlogWeb.ConnCase, async: true

  test "GET /snake 301-redirects to /games/snake", %{conn: conn} do
    conn = get(conn, ~p"/snake")
    assert redirected_to(conn, 301) == "/games/snake"
  end
end
```

- [ ] **Step 4: Compile the whole app**

Run: `mix compile --warnings-as-errors`
Expected: compiles cleanly (requires Tasks 7–10 modules to exist).

- [ ] **Step 5: Run the redirect test**

Run: `mix test test/blog_web/controllers/redirect_controller_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/blog_web/router.ex lib/blog_web/controllers/redirect_controller.ex test/blog_web/controllers/redirect_controller_test.exs
git commit -m "Route /games, /games/snake, /podcasts, /projects; 301 /snake"
```

---

## Task 7: SnakeLive → hero (route already moved in Task 6)

**Files:**
- Modify: `lib/blog_web/live/snake_live.ex`

- [ ] **Step 1: Use `page_hero` for the Snake title/intro**

In `lib/blog_web/live/snake_live.ex` `render/1`, replace the outer wrapper and the
existing `<h1>`/intro `<p>` so the title lives in the hero. Change the opening of
the template from:

```heex
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8" phx-window-keydown="key">
      <div class="mx-auto max-w-5xl">
        <h1 class="md:text-5xl text-sky-200">Snake</h1>
        <p class="text-gray-400 mb-6">
          A single global game — everyone here shares the board. Use
          <span class="text-zinc-200">arrow keys</span> or
          <span class="text-zinc-200">WASD</span> to steer your snake. Crash and you respawn.
        </p>
```

to:

```heex
    <.page_hero
      title="Snake"
      eyebrow="Games"
      subtitle="A single global game — everyone here shares the board. Arrow keys or WASD to steer; crash and you respawn."
    />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10" phx-window-keydown="key">
      <div class="mx-auto max-w-5xl">
```

The rest of the template (the `flex` row with the SVG board and player list)
stays as-is; ensure the two extra `<div>`s that were opened are still closed by
the existing closing tags (the original had two opening `<div>`s before the
board; the replacement also opens two, so the existing closers still balance).

- [ ] **Step 2: Compile**

Run: `mix compile --warnings-as-errors`
Expected: compiles cleanly.

- [ ] **Step 3: Manually verify**

Run: `mix phx.server`, open `http://localhost:4000/games/snake`.
Expected: "Snake" hero with shapes, board renders below on flat grey, arrow keys
steer. `http://localhost:4000/snake` 301-redirects here.

- [ ] **Step 4: Commit**

```bash
git add lib/blog_web/live/snake_live.ex
git commit -m "Snake page uses page_hero at /games/snake"
```

---

## Task 8: GamesLive.Index landing

**Files:**
- Create: `lib/blog_web/live/games_live/index.ex`
- Test: `test/blog_web/live/games_live_index_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/blog_web/live/games_live_index_test.exs`:

```elixir
defmodule BlogWeb.GamesLive.IndexTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "lists games and links Snake to /games/snake", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/games")

    assert html =~ "Games"
    assert html =~ "Snake"
    assert html =~ ~s|href="/games/snake"|
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/blog_web/live/games_live_index_test.exs`
Expected: FAIL — `GamesLive.Index` does not exist / route not found. (If the
route was not yet added in Task 6, add it now.)

- [ ] **Step 3: Create the LiveView**

Create `lib/blog_web/live/games_live/index.ex`:

```elixir
defmodule BlogWeb.GamesLive.Index do
  use BlogWeb, :live_view

  @games [
    %{
      name: "Snake",
      href: "/games/snake",
      blurb: "A single global multiplayer snake — everyone shares one board.",
      emoji: "🐍"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, games: @games, page_title: "Games | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero title="Games" subtitle="Little things to play with." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <.link
            :for={game <- @games}
            navigate={game.href}
            class="browser bg-zinc-800 p-6 no-underline block"
          >
            <div class="text-3xl mb-2">{game.emoji}</div>
            <h2 class="text-xl text-[color:var(--accent-heading)]">{game.name}</h2>
            <p class="text-sm text-zinc-400 mt-1">{game.blurb}</p>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/blog_web/live/games_live_index_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/blog_web/live/games_live/index.ex test/blog_web/live/games_live_index_test.exs
git commit -m "Add Games landing listing Snake"
```

---

## Task 9: PodcastLive.Index

**Files:**
- Create: `lib/blog_web/live/podcast_live/index.ex`
- Test: `test/blog_web/live/podcast_live_index_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/blog_web/live/podcast_live_index_test.exs`:

```elixir
defmodule BlogWeb.PodcastLive.IndexTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "shows the Software Unscripted appearance with a listen link", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/podcasts")

    assert html =~ "Podcasts"
    assert html =~ "Software Unscripted"
    assert html =~ "open.spotify.com/episode/6cnAHvdCXedoHxG4w9pWOV"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/blog_web/live/podcast_live_index_test.exs`
Expected: FAIL — module/route missing.

- [ ] **Step 3: Create the LiveView**

Create `lib/blog_web/live/podcast_live/index.ex`:

```elixir
defmodule BlogWeb.PodcastLive.Index do
  use BlogWeb, :live_view

  @appearances [
    %{
      show: "Software Unscripted",
      title: "Elm + Rust at StructionSite",
      blurb:
        "I shared our experience using Elm and Rust to build construction-tech tooling at StructionSite.",
      url: "https://open.spotify.com/episode/6cnAHvdCXedoHxG4w9pWOV"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, appearances: @appearances, page_title: "Podcasts | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero title="Podcasts" subtitle="Shows I've been a guest on." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <h4 class="text-lg text-gray-500 mb-4">Appearances</h4>
        <div :for={ep <- @appearances} class="browser bg-zinc-800 p-6 mb-6">
          <p class="font-fancy text-sm uppercase tracking-wide text-zinc-400">{ep.show}</p>
          <h2 class="text-xl text-[color:var(--accent-heading)] mt-1">{ep.title}</h2>
          <p class="text-sm text-zinc-400 mt-2">{ep.blurb}</p>
          <a class="link inline-block mt-3" href={ep.url}>Listen →</a>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/blog_web/live/podcast_live_index_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/blog_web/live/podcast_live/index.ex test/blog_web/live/podcast_live_index_test.exs
git commit -m "Add Podcasts page with Software Unscripted appearance"
```

---

## Task 10: ProjectLive.Index

**Files:**
- Create: `lib/blog_web/live/project_live/index.ex`
- Test: `test/blog_web/live/project_live_index_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/blog_web/live/project_live_index_test.exs`:

```elixir
defmodule BlogWeb.ProjectLive.IndexTest do
  use BlogWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders a coming soon message", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/projects")

    assert html =~ "Projects"
    assert html =~ "Coming soon"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/blog_web/live/project_live_index_test.exs`
Expected: FAIL — module/route missing.

- [ ] **Step 3: Create the LiveView**

Create `lib/blog_web/live/project_live/index.ex`:

```elixir
defmodule BlogWeb.ProjectLive.Index do
  use BlogWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Projects | Dan Bruder")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_hero title="Projects" subtitle="Things I'm building." />

    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-10">
      <div class="mx-auto max-w-3xl">
        <p class="text-zinc-400">Coming soon.</p>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/blog_web/live/project_live_index_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/blog_web/live/project_live/index.ex test/blog_web/live/project_live_index_test.exs
git commit -m "Add Projects coming-soon page"
```

---

## Task 11: Remove the Software Unscripted paragraph from the About page

The About page lives in the database (`posts` where `slug='about'`), not a content
file. Remove the podcast sentence so it lives only on `/podcasts`.

**Files:**
- Data: `blog_dev.db` (dev). Note: the production DB needs the same edit at deploy.

- [ ] **Step 1: Inspect the current sentence**

Run:
```bash
sqlite3 blog_dev.db "SELECT body FROM posts WHERE slug='about';"
```
Expected: body contains the line beginning
`I shared our experience using Elm + Rust at StructionSite on the [Software Unscripted]...`.

- [ ] **Step 2: Remove the sentence**

Run (removes the whole paragraph line, matching the leading space seen in the
source):
```bash
sqlite3 blog_dev.db "UPDATE posts SET body = replace(body, ' I shared our experience using Elm + Rust at StructionSite on the [Software Unscripted](https://open.spotify.com/episode/6cnAHvdCXedoHxG4w9pWOV) podcast last year.' || char(10) || char(10), '') WHERE slug='about';"
```

- [ ] **Step 3: Verify it's gone**

Run:
```bash
sqlite3 blog_dev.db "SELECT body LIKE '%Software Unscripted%' FROM posts WHERE slug='about';"
```
Expected: `0`.

- [ ] **Step 4: Manually verify the About page still renders**

Run: `mix phx.server`, open `http://localhost:4000/blog/about`.
Expected: About content intact, no Software Unscripted sentence, no broken
spacing.

- [ ] **Step 5: Note the prod edit**

No commit (DB is not in git). Record in the PR/deploy notes that the same
`UPDATE` must run against the production database.

---

## Task 12: Full verification pass

- [ ] **Step 1: Run the whole test suite**

Run: `mix test`
Expected: all tests pass. If any legacy test references `/snake` or old home copy,
fix it (only `home_live_test.exs` and `post_live_show_test.exs` were expected to
touch snake/home text; `post_live_show_test.exs` asserts the snake footer *text*
"have a go at the game of", which is unchanged, so it should still pass).

- [ ] **Step 2: Build assets and boot**

Run: `mix compile --warnings-as-errors` then `mix phx.server`.
Expected: clean compile; visit `/`, `/notes`, `/games`, `/games/snake`,
`/podcasts`, `/projects`, `/blog/about`, and one post — sidebar persists, shapes
appear only in heros, body is flat grey, active nav link highlights, mobile top
bar toggles.

- [ ] **Step 3: Final commit if any fixes were made**

```bash
git add -A
git commit -m "Fix up tests and verification for sidebar layout"
```

---

## Self-Review Notes

- **Spec coverage:** sidebar (Task 2), painted hero vs grey body (Tasks 1,3–5,7–10),
  Writing/Notes (3,4), Games landing + nested Snake + redirect (6,7,8),
  Podcasts (9), Projects (10), About edit (11), mobile collapse (2), active nav (2).
- **Ordering caveat:** Tasks 7–10 create modules the router (Task 6) references;
  execute 7–10 before compiling the router, or add the routes incrementally as
  each module lands. The plan calls this out in Task 6.
- **Type/name consistency:** module names `GamesLive.Index`, `PodcastLive.Index`,
  `ProjectLive.Index`, `RedirectController.snake/2`, component `page_hero` used
  consistently across router and pages.
