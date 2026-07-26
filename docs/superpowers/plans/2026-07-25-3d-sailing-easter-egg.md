# 3D Sailing Easter Egg Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a hidden third "Sea" theme that turns the blog into a shared 3D toon ocean where every page is an island, visitors reading a page appear as boats anchored at that island, and visitors in Sea mode sail around live in real time.

**Architecture:** A per-tab `sailor_id` (generated pre-paint) is sent both as a LiveView connect param and as a `SeaChannel` join param, correlating two data layers: (1) a low-frequency **roster** read from the existing `site_presence` Presence and delivered over `SeaChannel`, which anchors reader-boats at their page's island; (2) a high-frequency **position** fan-out over the same channel for people actively sailing. The 3D scene (three.js) is built as a **separate esbuild ESM bundle** dynamically `import()`-ed only when the theme flips to `sea`, so normal page loads are untouched.

**Tech Stack:** Elixir/Phoenix 1.7, Phoenix LiveView 1.0, Phoenix Channels + Presence, esbuild (two profiles: iife `blog`, esm `sea`), three.js (~0.169), Tailwind system-v2 tokens.

---

## File Structure

**New files**
- `lib/blog_web/sea_world.ex` — derives the island list (path → title → section → x/z) from routes + `Blog.Content`.
- `lib/blog_web/channels/sea_channel.ex` — roster delivery + position fan-out.
- `lib/blog_web/channels/user_socket.ex` — socket hosting `sea:*` channels.
- `assets/js/sea/index.js` — Sea bundle entry: `startSea(opts)` / `stopSea()`, render loop, docking.
- `assets/js/sea/scene.js` — `SeaScene` class: renderer, camera, sky/water, island + boat meshes, toon+outline.
- `assets/js/sea/controls.js` — keyboard + touch steering → a shared input state.
- `assets/js/sea/net.js` — `SeaNet`: channel join, roster + position events, interpolation buffer.
- `assets/js/sea/world.js` — island parsing + docking-distance helpers (pure, no three.js).
- `test/blog_web/sea_world_test.exs`
- `test/blog_web/channels/sea_channel_test.exs`

**Modified files**
- `assets/package.json` — add `three`.
- `config/config.exs` — add `sea` esbuild profile; add `--external:/assets/*` to `blog` profile.
- `config/dev.exs` — add esbuild `sea` watcher.
- `mix.exs` — `assets.build` / `assets.deploy` run the `sea` profile too.
- `lib/blog_web/endpoint.ex` — mount `UserSocket` at `/socket`.
- `lib/blog_web/live/presence_tracker.ex` — track `sailor_id` + `path` in presence meta.
- `lib/blog_web/components/layouts/root.html.heex` — pre-paint `SAILOR_ID`; tolerate `sea` theme.
- `lib/blog_web/components/layouts/app.html.heex` — Sea overlay container + `data-islands`; 3-state theme button.
- `assets/js/app.js` — pass `sailor_id` connect param; 3-state `ThemeToggle`; `SeaMode` hook.

---

## Task 1: Build infrastructure — three.js + separate ESM `sea` bundle

**Files:**
- Modify: `assets/package.json`
- Modify: `config/config.exs:21-27` (esbuild `blog` profile) and add `sea` profile
- Modify: `config/dev.exs` (watchers)
- Modify: `mix.exs` (`assets.build`, `assets.deploy` aliases)

- [ ] **Step 1: Add three.js to assets deps**

Edit `assets/package.json` `dependencies` to:

```json
  "dependencies": {
    "highlight.js": "^11.11.1",
    "three": "^0.169.0"
  }
```

- [ ] **Step 2: Install it**

Run: `npm install --prefix assets`
Expected: `assets/node_modules/three` now exists. Verify:
Run: `test -d assets/node_modules/three && echo OK`
Expected: `OK`

- [ ] **Step 3: Add the `sea` esbuild profile and make the app bundle treat `/assets/*` as external**

In `config/config.exs`, replace the `config :esbuild` block with:

```elixir
config :esbuild,
  version: "0.21.5",
  blog: [
    args:
      ~w(js/app.js js/paintWorklet.js --bundle --target=es2020 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --external:/assets/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  sea: [
    args:
      ~w(js/sea/index.js --bundle --format=esm --target=es2020 --outdir=../priv/static/assets/js/sea),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
```

The `--external:/assets/*` lets `app.js` keep a runtime `import("/assets/js/sea/index.js")` without esbuild trying to bundle it. The `sea` profile emits an ES module so it can be dynamically imported.

- [ ] **Step 4: Add the `sea` watcher in dev**

In `config/dev.exs`, find the `watchers:` list (it contains an `esbuild:` entry like `{Esbuild, :install_and_run, [:blog, ~w(--sourcemap=inline --watch)]}`). Add a second esbuild watcher right after it:

```elixir
      esbuild: {Esbuild, :install_and_run, [:blog, ~w(--sourcemap=inline --watch)]},
      esbuild_sea: {Esbuild, :install_and_run, [:sea, ~w(--sourcemap=inline --watch)]},
```

(The watcher key just needs to be unique; `esbuild_sea` is fine.)

- [ ] **Step 5: Wire the `sea` profile into build/deploy aliases**

In `mix.exs`, update the two aliases:

```elixir
      "assets.build": ["tailwind blog", "esbuild blog", "esbuild sea"],
```

and

```elixir
      "assets.deploy": [
        "tailwind blog --minify",
        "esbuild blog --minify",
        "esbuild sea --minify",
        "phx.digest"
      ],
```

- [ ] **Step 6: Create a stub entry so the build succeeds now**

Create `assets/js/sea/index.js`:

```javascript
// Sea bundle entry. Real implementation lands in later tasks.
export function startSea() {}
export function stopSea() {}
```

- [ ] **Step 7: Build and verify the chunk is emitted and separate**

Run: `mix esbuild sea`
Expected: exits 0 and creates `priv/static/assets/js/sea/index.js`. Verify:
Run: `test -f priv/static/assets/js/sea/index.js && echo OK`
Expected: `OK`

Run: `mix esbuild blog`
Expected: exits 0. Confirm three.js did NOT leak into the app bundle:
Run: `grep -c "three" priv/static/assets/js/app.js || true`
Expected: `0` (the app bundle must not contain three.js).

- [ ] **Step 8: Commit**

```bash
git add assets/package.json assets/package-lock.json config/config.exs config/dev.exs mix.exs assets/js/sea/index.js
git commit -m "build: add three.js and a separate lazy-loaded sea esbuild bundle"
```

---

## Task 2: `BlogWeb.SeaWorld` — derive islands from content

Islands are derived so publishing a post automatically adds an island. Home `/` is the harbor at the origin; section index pages and every published post/note get an island. Positions are deterministic (stable across reloads) and clustered by section.

**Files:**
- Create: `lib/blog_web/sea_world.ex`
- Test: `test/blog_web/sea_world_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/blog_web/sea_world_test.exs`:

```elixir
defmodule BlogWeb.SeaWorldTest do
  use Blog.DataCase, async: true

  alias BlogWeb.SeaWorld

  test "always includes the harbor at the origin" do
    harbor = Enum.find(SeaWorld.islands(), &(&1.path == "/"))
    assert harbor.section == "harbor"
    assert harbor.x == 0.0
    assert harbor.z == 0.0
    assert harbor.title == "Harbor"
  end

  test "includes the fixed section index islands" do
    paths = SeaWorld.islands() |> Enum.map(& &1.path)

    for p <- ["/writing", "/notes", "/podcasts", "/projects", "/games"] do
      assert p in paths, "expected island for #{p}"
    end
  end

  test "includes an island for each published post and note" do
    {:ok, post} =
      Blog.Content.create_post(%{
        title: "Hello Sea",
        slug: "hello-sea",
        kind: "post",
        published: true
      })

    {:ok, _note} =
      Blog.Content.create_post(%{
        title: "A Note",
        slug: "a-note",
        kind: "note",
        published: true
      })

    by_path = SeaWorld.islands() |> Map.new(&{&1.path, &1})

    assert by_path["/blog/hello-sea"].title == "Hello Sea"
    assert by_path["/blog/hello-sea"].section == "writing"
    assert by_path["/notes/a-note"].title == "A Note"
    assert by_path["/notes/a-note"].section == "notes"

    # Positions are deterministic and non-origin for non-harbor islands.
    assert {by_path["/blog/hello-sea"].x, by_path["/blog/hello-sea"].z} != {0.0, 0.0}
    refute post.id == nil
  end

  test "positions are stable across calls" do
    a = SeaWorld.islands() |> Map.new(&{&1.path, {&1.x, &1.z}})
    b = SeaWorld.islands() |> Map.new(&{&1.path, {&1.x, &1.z}})
    assert a == b
  end

  test "unpublished posts get no island" do
    {:ok, _} =
      Blog.Content.create_post(%{
        title: "Secret",
        slug: "secret-draft",
        kind: "post",
        published: false
      })

    refute Enum.any?(SeaWorld.islands(), &(&1.path == "/blog/secret-draft"))
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `mix test test/blog_web/sea_world_test.exs`
Expected: FAIL — `BlogWeb.SeaWorld` is undefined.

- [ ] **Step 3: Implement `SeaWorld`**

Create `lib/blog_web/sea_world.ex`:

```elixir
defmodule BlogWeb.SeaWorld do
  @moduledoc """
  Derives the archipelago for the Sea easter egg: one island per significant
  public route. Home (`/`) is the harbor at the origin; section index pages and
  every published post/note get an island. Positions are deterministic (a stable
  hash of the path) and clustered by section so the layout is the same for
  everyone and stable across reloads. Publishing a post automatically adds an
  island the next time the page loads.
  """

  alias Blog.Content

  # Section index islands and the order/angle each section's cluster sits at.
  @sections [
    {"harbor", "/", "Harbor"},
    {"writing", "/writing", "Writing"},
    {"notes", "/notes", "Notes"},
    {"podcasts", "/podcasts", "Podcasts"},
    {"projects", "/projects", "Projects"},
    {"games", "/games", "Games"}
  ]

  # Extra fixed islands that aren't posts and aren't section indexes.
  @extra [
    {"games", "/games/snake", "Snake"},
    {"games", "/games/sand", "Falling Sand"}
  ]

  @type island :: %{
          path: String.t(),
          title: String.t(),
          section: String.t(),
          x: float(),
          z: float()
        }

  @spec islands() :: [island()]
  def islands do
    fixed =
      Enum.map(@sections, fn {section, path, title} -> {section, path, title} end) ++ @extra

    posts =
      Enum.map(Content.list_published_posts(), fn p ->
        {"writing", "/blog/#{p.slug}", p.title}
      end)

    notes =
      Enum.map(Content.list_published_notes(), fn p ->
        {"notes", "/notes/#{p.slug}", p.title}
      end)

    (fixed ++ posts ++ notes)
    |> Enum.map(fn {section, path, title} ->
      {x, z} = position(section, path)
      %{path: path, title: title, section: section, x: x, z: z}
    end)
  end

  # Harbor sits dead center; everything else is placed in its section's angular
  # sector, pushed out to a radius derived from a stable hash of the path.
  defp position("harbor", "/"), do: {0.0, 0.0}

  defp position(section, path) do
    sector = section_angle(section)
    # Deterministic spread within the sector.
    h = :erlang.phash2(path)
    jitter = rem(h, 40) / 40 * 0.7 - 0.35
    angle = sector + jitter
    radius = 45 + rem(div(h, 40), 8) * 26 + rem(div(h, 320), 5) * 6
    {Float.round(radius * :math.cos(angle), 2), Float.round(radius * :math.sin(angle), 2)}
  end

  defp section_angle(section) do
    idx =
      @sections
      |> Enum.map(fn {s, _, _} -> s end)
      |> Enum.find_index(&(&1 == section)) || 0

    idx * (2 * :math.pi() / length(@sections))
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/blog_web/sea_world_test.exs`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/blog_web/sea_world.ex test/blog_web/sea_world_test.exs
git commit -m "feat: derive sailing-world islands from content"
```

---

## Task 3: Presence meta — carry `sailor_id` and `path`

Reader-boats are anchored at the island of the page they are on and fly their country flag. That requires the presence meta to know the current `path` (which island) and a stable per-tab `sailor_id` (so a live sailor's anchored boat can be reconciled with their moving boat).

**Files:**
- Modify: `lib/blog_web/live/presence_tracker.ex`
- Modify: `assets/js/app.js` (connect param) and `lib/blog_web/components/layouts/root.html.heex` (generate the id)
- Test: `test/blog_web/live/presence_tracker_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/blog_web/live/presence_tracker_test.exs`:

```elixir
defmodule BlogWeb.PresenceTrackerTest do
  use BlogWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  test "a connected viewer is tracked with a path in the meta", %{conn: conn} do
    {:ok, _lv, _html} = live(conn, "/writing")

    # Give the async track + handle_params a moment.
    metas =
      wait_for(fn ->
        case Presence.list(PresenceTracker.topic()) do
          m when map_size(m) > 0 -> m
          _ -> nil
        end
      end)

    [{_key, %{metas: [meta | _]}} | _] = Map.to_list(metas)
    assert meta.path == "/writing"
    assert Map.has_key?(meta, :sailor_id)
  end

  defp wait_for(fun, tries \\ 50) do
    case fun.() do
      nil when tries > 0 ->
        Process.sleep(20)
        wait_for(fun, tries - 1)

      result ->
        result
    end
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `mix test test/blog_web/live/presence_tracker_test.exs`
Expected: FAIL — `meta.path` is missing (KeyError / assertion failure).

- [ ] **Step 3: Track `sailor_id` at mount and `path` on navigation**

Replace `lib/blog_web/live/presence_tracker.ex` with:

```elixir
defmodule BlogWeb.PresenceTracker do
  @moduledoc """
  `on_mount` hook that tracks each connected public LiveView as a live
  viewer under the #{inspect(__MODULE__)}.topic/0 presence topic. The meta
  carries a best-effort `country`, the client-supplied `sailor_id` (stable per
  browser tab, used to correlate a reader's anchored boat with their live boat
  in the Sea easter egg), and the current `path` (which island the viewer sits
  at), kept up to date as they navigate. Also keeps a live `:viewer_count`
  assign for the site-wide viewer bubble.
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  alias BlogWeb.Presence

  @topic "site_presence"

  def topic, do: @topic

  def on_mount(:track, _params, _session, socket) do
    if connected?(socket) do
      country = socket |> client_ip() |> Blog.GeoIP.country_for_ip()
      sailor_id = get_connect_params(socket)["sailor_id"]

      {:ok, _ref} =
        Presence.track(self(), @topic, socket.id, %{
          country: country,
          sailor_id: sailor_id,
          path: nil,
          joined_at: System.system_time(:second)
        })

      Phoenix.PubSub.subscribe(Blog.PubSub, @topic)
    end

    socket =
      socket
      |> assign(:viewer_count, viewer_count())
      |> attach_hook(:presence_viewer_count, :handle_info, &handle_presence_diff/2)
      |> attach_hook(:presence_path, :handle_params, &track_path/3)

    {:cont, socket}
  end

  defp track_path(_params, uri, socket) do
    if connected?(socket) do
      path = URI.parse(uri).path

      Presence.update(self(), @topic, socket.id, fn meta ->
        Map.put(meta, :path, path)
      end)
    end

    {:cont, socket}
  end

  defp handle_presence_diff(%{event: "presence_diff"}, socket) do
    {:halt, assign(socket, :viewer_count, viewer_count())}
  end

  defp handle_presence_diff(_message, socket), do: {:cont, socket}

  defp viewer_count, do: @topic |> Presence.list() |> map_size()

  defp client_ip(socket) do
    x_headers = get_connect_info(socket, :x_headers) || []

    case List.keyfind(x_headers, "x-forwarded-for", 0) do
      {_, value} ->
        value |> String.split(",") |> List.first() |> String.trim()

      nil ->
        case get_connect_info(socket, :peer_data) do
          %{address: address} -> address |> :inet.ntoa() |> to_string()
          _ -> nil
        end
    end
  end
end
```

- [ ] **Step 4: Generate `SAILOR_ID` pre-paint and pass it as a connect param**

In `lib/blog_web/components/layouts/root.html.heex`, extend the existing pre-paint `<script>` (the one that sets the theme) so it also mints a per-tab id. Replace that script block with:

```html
    <%!-- Set the theme before first paint so there's no flash, and mint a
          stable per-tab id used by the Sea easter egg's presence + channel. --%>
    <script>
      (function () {
        var t = localStorage.theme ||
          (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
        document.documentElement.dataset.theme = t;
        var id = sessionStorage.sailorId;
        if (!id) {
          id = (crypto.randomUUID && crypto.randomUUID()) ||
            String(Date.now()) + Math.random().toString(16).slice(2);
          sessionStorage.sailorId = id;
        }
        window.SAILOR_ID = id;
      })();
    </script>
```

- [ ] **Step 5: Send the id on the LiveView connect**

In `assets/js/app.js`, update the `LiveSocket` params:

```javascript
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: {_csrf_token: csrfToken, sailor_id: window.SAILOR_ID}
})
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/blog_web/live/presence_tracker_test.exs`
Expected: PASS.

Run: `mix test`
Expected: PASS (no regressions in existing tests).

- [ ] **Step 7: Commit**

```bash
git add lib/blog_web/live/presence_tracker.ex test/blog_web/live/presence_tracker_test.exs lib/blog_web/components/layouts/root.html.heex assets/js/app.js
git commit -m "feat: track sailor_id and path in presence meta"
```

---

## Task 4: `SeaChannel` + `UserSocket` — roster + position sync

The channel delivers the roster (all connected visitors, from `site_presence`) to sailors and fans out live positions. Identity flows via the `sailor_id` join param.

**Files:**
- Create: `test/support/channel_case.ex` (does not exist yet — no channels in the project so far)
- Create: `lib/blog_web/channels/user_socket.ex`
- Create: `lib/blog_web/channels/sea_channel.ex`
- Modify: `lib/blog_web/endpoint.ex` (mount the socket)
- Test: `test/blog_web/channels/sea_channel_test.exs`

- [ ] **Step 0: Create the `ChannelCase` test support (it doesn't exist yet)**

Create `test/support/channel_case.ex`:

```elixir
defmodule BlogWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import BlogWeb.ChannelCase

      # The default endpoint for testing
      @endpoint BlogWeb.Endpoint
    end
  end

  setup tags do
    Blog.DataCase.setup_sandbox(tags)
    :ok
  end
end
```

This depends on `Blog.DataCase.setup_sandbox/1`. Confirm that function exists in `test/support/data_case.ex` (the standard Phoenix generator provides it). If it is named differently there, match the existing sandbox setup used by `Blog.DataCase`.

- [ ] **Step 1: Create the socket**

Create `lib/blog_web/channels/user_socket.ex`:

```elixir
defmodule BlogWeb.UserSocket do
  use Phoenix.Socket

  channel "sea:*", BlogWeb.SeaChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
```

- [ ] **Step 2: Mount the socket in the endpoint**

In `lib/blog_web/endpoint.ex`, directly below the existing `socket("/live", ...)` declaration, add:

```elixir
  socket("/socket", BlogWeb.UserSocket, websocket: true, longpoll: false)
```

- [ ] **Step 3: Write the failing channel test**

Create `test/blog_web/channels/sea_channel_test.exs`:

```elixir
defmodule BlogWeb.SeaChannelTest do
  use BlogWeb.ChannelCase

  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  defp join_sea(sailor_id) do
    {:ok, socket} = connect(BlogWeb.UserSocket, %{}, %{})
    subscribe_and_join(socket, "sea:ocean", %{"sailor_id" => sailor_id})
  end

  test "on join the client receives the current roster" do
    # Seed a reader into site presence directly.
    {:ok, _} =
      Presence.track(self(), PresenceTracker.topic(), "reader-key", %{
        country: "US",
        sailor_id: "reader-1",
        path: "/writing",
        joined_at: 0
      })

    {:ok, _reply, _socket} = join_sea("sailor-1")

    assert_push "roster", %{sailors: sailors}
    reader = Enum.find(sailors, &(&1.id == "reader-1"))
    assert reader.path == "/writing"
    assert reader.flag == "🇺🇸"
  end

  test "positions broadcast to other members but not the sender" do
    {:ok, _r1, socket1} = join_sea("sailor-1")
    {:ok, _r2, _socket2} = join_sea("sailor-2")

    push(socket1, "pos", %{"x" => 1.5, "z" => -2.0, "h" => 0.25})

    # socket1 is the sender; it must NOT receive its own position back.
    refute_push "pos", %{id: "sailor-1"}, 100

    # A second member joined via the same test process, so the broadcast is
    # delivered to this process too, tagged with the sender's id.
    assert_broadcast "pos", %{id: "sailor-1", x: 1.5, z: -2.0, h: 0.25}
  end

  test "leaving broadcasts a gone event" do
    {:ok, _r1, socket1} = join_sea("sailor-1")
    ref = leave(socket1)
    assert_reply ref, :ok
    assert_broadcast "gone", %{id: "sailor-1"}
  end
end
```

- [ ] **Step 4: Run it to verify it fails**

Run: `mix test test/blog_web/channels/sea_channel_test.exs`
Expected: FAIL — `BlogWeb.SeaChannel` is undefined.

- [ ] **Step 5: Implement the channel**

Create `lib/blog_web/channels/sea_channel.ex`:

```elixir
defmodule BlogWeb.SeaChannel do
  @moduledoc """
  Real-time layer for the Sea easter egg. On join, a sailor receives the roster
  of everyone currently on the site (derived from the `site_presence` Presence,
  each entry reduced to id/path/flag) so reader-boats can be anchored at the
  right island. Sailors then broadcast their `{x, z, h}` position, which is
  fanned out to the other members and rendered as a live boat. Everything here
  is ephemeral — no storage.
  """

  use Phoenix.Channel

  alias BlogWeb.Presence
  alias BlogWeb.PresenceTracker

  @impl true
  def join("sea:ocean", %{"sailor_id" => sailor_id}, socket) do
    send(self(), :after_join)
    Phoenix.PubSub.subscribe(Blog.PubSub, PresenceTracker.topic())
    {:ok, assign(socket, :sailor_id, sailor_id)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    push(socket, "roster", %{sailors: roster()})
    {:noreply, socket}
  end

  # A reader joined/left/navigated: refresh the roster for this sailor.
  def handle_info(%{event: "presence_diff"}, socket) do
    push(socket, "roster", %{sailors: roster()})
    {:noreply, socket}
  end

  @impl true
  def handle_in("pos", %{"x" => x, "z" => z, "h" => h}, socket) do
    broadcast_from!(socket, "pos", %{id: socket.assigns.sailor_id, x: x, z: z, h: h})
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if id = socket.assigns[:sailor_id] do
      broadcast!(socket, "gone", %{id: id})
    end

    :ok
  end

  defp roster do
    PresenceTracker.topic()
    |> Presence.list()
    |> Enum.map(fn {key, %{metas: [meta | _]}} ->
      %{
        id: meta[:sailor_id] || key,
        path: meta[:path],
        flag: flag(meta[:country])
      }
    end)
  end

  # ISO-3166 alpha-2 -> regional-indicator flag emoji. Mirrors the admin
  # presence view's helper.
  defp flag(<<a, b>>) when a in ?A..?Z and b in ?A..?Z do
    <<127_397 + a::utf8, 127_397 + b::utf8>>
  end

  defp flag(_), do: "🏳️"
end
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/blog_web/channels/sea_channel_test.exs`
Expected: PASS (all 3 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/blog_web/channels/user_socket.ex lib/blog_web/channels/sea_channel.ex lib/blog_web/endpoint.ex test/blog_web/channels/sea_channel_test.exs
git commit -m "feat: add SeaChannel for roster + live position sync"
```

---

## Task 5: Theme becomes 3-state + Sea overlay container

Extend the Light → Dark toggle to Light → Dark → Sea, add the full-screen overlay the scene mounts into (carrying the island data), and dispatch a `theme:changed` event the Sea hook listens for.

**Files:**
- Modify: `lib/blog_web/components/layouts/app.html.heex`
- Modify: `assets/js/app.js`

- [ ] **Step 1: Add the overlay container + island data + 3-state button**

In `lib/blog_web/components/layouts/app.html.heex`, change the theme-toggle button (currently labelled `Dark`) to start empty (the hook sets its label) and give it the hook — it already has `phx-hook="ThemeToggle"`, so only remove the hard-coded `Dark` text:

```html
          <button
            id="theme-toggle"
            phx-hook="ThemeToggle"
            type="button"
            class="border border-ink px-2 py-1 text-[10.5px] font-semibold uppercase tracking-[0.12em] text-ink transition-colors hover:bg-lime hover:text-on-lime"
          ></button>
```

Then, at the very end of the file (after the closing `</div>` of the layout grid), add the Sea overlay:

```html
<div
  id="sea-overlay"
  phx-hook="SeaMode"
  phx-update="ignore"
  data-islands={Jason.encode!(BlogWeb.SeaWorld.islands())}
  class="fixed inset-0 z-[9999] hidden"
></div>
```

`phx-update="ignore"` keeps LiveView from touching the canvas the hook manages. It stays `hidden` until Sea mode turns it on.

- [ ] **Step 2: Make `ThemeToggle` cycle three states and announce changes**

In `assets/js/app.js`, replace the `ThemeToggle` hook with:

```javascript
  // Theme toggle cycles Light -> Dark -> Sea (a hidden 3D easter egg) -> Light.
  // Theme is a client concern: set dataset.theme on <html>, persist, and
  // broadcast a `theme:changed` event the SeaMode hook listens for. The label
  // names the mode you'd switch TO next.
  ThemeToggle: {
    order: ["light", "dark", "sea"],
    labelFor(theme) {
      const next = this.order[(this.order.indexOf(theme) + 1) % this.order.length]
      return next === "sea" ? "Sea" : next === "dark" ? "Dark" : "Light"
    },
    apply(theme) {
      document.documentElement.dataset.theme = theme
      localStorage.theme = theme
      this.el.textContent = this.labelFor(theme)
      document.dispatchEvent(new CustomEvent("theme:changed", {detail: {theme}}))
    },
    mounted() {
      const current = this.order.includes(document.documentElement.dataset.theme)
        ? document.documentElement.dataset.theme
        : "light"
      this.el.textContent = this.labelFor(current)
      this.el.addEventListener("click", () => {
        const now = this.order.includes(document.documentElement.dataset.theme)
          ? document.documentElement.dataset.theme
          : "light"
        this.apply(this.order[(this.order.indexOf(now) + 1) % this.order.length])
      })
    }
  },
```

- [ ] **Step 3: Add the `SeaMode` hook (lazy-loads the sea bundle)**

In `assets/js/app.js`, add this hook to the `Hooks` object (e.g. right after `ThemeToggle`):

```javascript
  // Mounts/*unmounts* the 3D sea when the theme is "sea". The heavy three.js
  // bundle is only imported the first time it's needed.
  SeaMode: {
    async enter() {
      if (this.running) return
      this.running = true
      this.el.classList.remove("hidden")
      const mod = await import("/assets/js/sea/index.js")
      this.sea = mod
      mod.startSea({
        el: this.el,
        sailorId: window.SAILOR_ID,
        islands: JSON.parse(this.el.dataset.islands || "[]")
      })
    },
    exit() {
      if (!this.running) return
      this.running = false
      if (this.sea) this.sea.stopSea()
      this.el.classList.add("hidden")
    },
    mounted() {
      this.onTheme = (e) => (e.detail.theme === "sea" ? this.enter() : this.exit())
      document.addEventListener("theme:changed", this.onTheme)
      // Honor a persisted "sea" theme on first load.
      if (document.documentElement.dataset.theme === "sea") this.enter()
    },
    destroyed() {
      document.removeEventListener("theme:changed", this.onTheme)
      this.exit()
    }
  },
```

- [ ] **Step 4: Tolerate the `sea` theme pre-paint**

No change needed — the pre-paint script in `root.html.heex` (Task 3, Step 4) already assigns whatever `localStorage.theme` holds, including `"sea"`, and the `SeaMode` hook picks it up on mount. Verify by reading the block; if `localStorage.theme` were validated against a list anywhere, add `"sea"`. (It is not.)

- [ ] **Step 5: Build and verify the app bundle still compiles**

Run: `mix esbuild blog`
Expected: exits 0, no errors.

- [ ] **Step 6: Manual check (terminal only — full 3D verified later)**

Run: `mix phx.server` (or use the `/run` skill).
Open the site, click the theme toggle three times, and confirm the label cycles Light → Dark → Sea → Light and that reaching "Sea" un-hides a full-screen overlay (currently empty — scene lands next). Toggling away re-hides it. Confirm normal reading is unaffected in Light/Dark.

- [ ] **Step 7: Commit**

```bash
git add lib/blog_web/components/layouts/app.html.heex assets/js/app.js
git commit -m "feat: add Sea as a third theme state with a lazy-loaded overlay"
```

---

## Task 6: `world.js` — island parsing + docking math (pure)

Small, pure helpers with no three.js, so the render loop and docking logic stay simple.

**Files:**
- Create: `assets/js/sea/world.js`

- [ ] **Step 1: Implement**

Create `assets/js/sea/world.js`:

```javascript
// Pure helpers for the sea world: island data + docking distance. No three.js
// here so this stays trivial to reason about.

export const DOCK_RADIUS = 9

// Returns the nearest island within DOCK_RADIUS of (x, z), or null.
export function nearestDockable(x, z, islands) {
  let best = null
  let bestD = DOCK_RADIUS * DOCK_RADIUS
  for (const isl of islands) {
    const dx = isl.x - x
    const dz = isl.z - z
    const d = dx * dx + dz * dz
    if (d < bestD) {
      bestD = d
      best = isl
    }
  }
  return best
}

// Island whose center is nearest (x, z) regardless of distance — used to label
// the island you're approaching.
export function nearestIsland(x, z, islands) {
  let best = null
  let bestD = Infinity
  for (const isl of islands) {
    const dx = isl.x - x
    const dz = isl.z - z
    const d = dx * dx + dz * dz
    if (d < bestD) {
      bestD = d
      best = isl
    }
  }
  return best ? {island: best, distance: Math.sqrt(bestD)} : null
}
```

- [ ] **Step 2: Commit**

```bash
git add assets/js/sea/world.js
git commit -m "feat: sea world docking helpers"
```

---

## Task 7: `scene.js` — the toon ocean, islands, boats

The `SeaScene` class owns all three.js. Bold cel look: flat `MeshToonMaterial` fills, thick ink outlines via an inverted back-side hull, paper sky, signal-blue water, lime islands, all from the system-v2 palette.

**Files:**
- Create: `assets/js/sea/scene.js`

- [ ] **Step 1: Implement**

Create `assets/js/sea/scene.js`:

```javascript
import * as THREE from "three"

// system-v2 palette, approximated in sRGB hex (the CSS uses oklch).
const COL = {
  paper: 0xeef0ec,
  ink: 0x1a1c20,
  lime: 0xc4e600,
  limeDark: 0xa9c700,
  sea: 0x3d4fd4,
  seaDark: 0x2f3ba8
}

// A 3-step toon gradient so MeshToonMaterial reads as flat cel bands.
function toonGradient() {
  const data = new Uint8Array([90, 160, 255])
  const tex = new THREE.DataTexture(data, data.length, 1, THREE.RedFormat)
  tex.needsUpdate = true
  return tex
}

// Ink outline: a slightly larger back-side copy of a geometry.
function outline(geometry, scale = 1.06) {
  const mat = new THREE.MeshBasicMaterial({color: COL.ink, side: THREE.BackSide})
  const mesh = new THREE.Mesh(geometry, mat)
  mesh.scale.multiplyScalar(scale)
  return mesh
}

export class SeaScene {
  constructor(container) {
    this.container = container
    this.gradient = toonGradient()

    this.renderer = new THREE.WebGLRenderer({antialias: true})
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.renderer.setSize(container.clientWidth, container.clientHeight)
    container.appendChild(this.renderer.domElement)

    this.scene = new THREE.Scene()
    this.scene.background = new THREE.Color(COL.paper)
    this.scene.fog = new THREE.Fog(COL.paper, 120, 320)

    this.camera = new THREE.PerspectiveCamera(
      55,
      container.clientWidth / container.clientHeight,
      0.1,
      1000
    )
    this.camera.position.set(0, 24, 34)

    const sun = new THREE.DirectionalLight(0xffffff, 2.2)
    sun.position.set(30, 60, 20)
    this.scene.add(sun)
    this.scene.add(new THREE.HemisphereLight(COL.paper, COL.seaDark, 1.1))

    this._water()

    this.boats = new Map() // id -> {group}
    this._onResize = () => this.resize()
    window.addEventListener("resize", this._onResize)
  }

  _water() {
    const geo = new THREE.PlaneGeometry(1200, 1200, 60, 60)
    geo.rotateX(-Math.PI / 2)
    this.waterGeo = geo
    this.waterBase = Float32Array.from(geo.attributes.position.array)
    const mat = new THREE.MeshToonMaterial({color: COL.sea, gradientMap: this.gradient})
    this.water = new THREE.Mesh(geo, mat)
    this.scene.add(this.water)
  }

  addIsland(island) {
    const group = new THREE.Group()
    const geo = new THREE.ConeGeometry(7, 9, 5)
    const mat = new THREE.MeshToonMaterial({color: COL.lime, gradientMap: this.gradient})
    const cone = new THREE.Mesh(geo, mat)
    cone.position.y = 3
    group.add(outline(geo).translateY(3))
    group.add(cone)

    // A little ink post so the island reads as a marker.
    const postGeo = new THREE.CylinderGeometry(0.25, 0.25, 6)
    const post = new THREE.Mesh(postGeo, new THREE.MeshBasicMaterial({color: COL.ink}))
    post.position.y = 9
    group.add(post)

    group.position.set(island.x, 0, island.z)
    group.userData.island = island
    this.scene.add(group)
    return group
  }

  // Boat: ink-outlined hull + a lime sail carrying a flag canvas texture.
  makeBoat(flagTexture, isSelf) {
    const group = new THREE.Group()

    const hullGeo = new THREE.BoxGeometry(2.4, 1.1, 4.2)
    const hull = new THREE.Mesh(
      hullGeo,
      new THREE.MeshToonMaterial({color: isSelf ? COL.lime : COL.paper, gradientMap: this.gradient})
    )
    hull.position.y = 1
    group.add(outline(hullGeo, 1.12).translateY(1))
    group.add(hull)

    const mastGeo = new THREE.CylinderGeometry(0.12, 0.12, 4)
    const mast = new THREE.Mesh(mastGeo, new THREE.MeshBasicMaterial({color: COL.ink}))
    mast.position.set(0, 3.2, 0.2)
    group.add(mast)

    const sailGeo = new THREE.PlaneGeometry(2.6, 2.6)
    const sailMat = new THREE.MeshBasicMaterial({
      map: flagTexture,
      side: THREE.DoubleSide
    })
    const sail = new THREE.Mesh(sailGeo, sailMat)
    sail.position.set(0, 3.1, 0.2)
    group.add(sail)

    if (isSelf) {
      const ring = new THREE.Mesh(
        new THREE.RingGeometry(3.2, 3.8, 24),
        new THREE.MeshBasicMaterial({color: COL.lime, side: THREE.DoubleSide})
      )
      ring.rotateX(-Math.PI / 2)
      ring.position.y = 0.2
      group.add(ring)
    }

    this.scene.add(group)
    return group
  }

  removeBoat(group) {
    this.scene.remove(group)
  }

  // Cheap animated swell.
  animateWater(t) {
    const pos = this.waterGeo.attributes.position
    const base = this.waterBase
    for (let i = 0; i < pos.count; i++) {
      const x = base[i * 3]
      const z = base[i * 3 + 2]
      pos.array[i * 3 + 1] = Math.sin(x * 0.05 + t) * 0.6 + Math.cos(z * 0.05 + t * 0.8) * 0.6
    }
    pos.needsUpdate = true
  }

  // Chase cam behind a boat group at heading h (radians).
  chase(target, h) {
    const back = new THREE.Vector3(Math.sin(h), 0, Math.cos(h))
    const desired = new THREE.Vector3(
      target.x - back.x * 34,
      22,
      target.z - back.z * 34
    )
    this.camera.position.lerp(desired, 0.08)
    this.camera.lookAt(target.x, 2, target.z)
  }

  render() {
    this.renderer.render(this.scene, this.camera)
  }

  resize() {
    const w = this.container.clientWidth
    const h = this.container.clientHeight
    this.renderer.setSize(w, h)
    this.camera.aspect = w / h
    this.camera.updateProjectionMatrix()
  }

  dispose() {
    window.removeEventListener("resize", this._onResize)
    this.renderer.dispose()
    if (this.renderer.domElement.parentNode) {
      this.renderer.domElement.parentNode.removeChild(this.renderer.domElement)
    }
  }
}

// Builds a CanvasTexture showing an emoji flag on a lime sail.
export function flagTexture(flag) {
  const c = document.createElement("canvas")
  c.width = c.height = 128
  const ctx = c.getContext("2d")
  ctx.fillStyle = "#c4e600"
  ctx.fillRect(0, 0, 128, 128)
  ctx.font = "72px system-ui, 'Apple Color Emoji', 'Segoe UI Emoji', sans-serif"
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"
  ctx.fillText(flag || "🏳️", 64, 70)
  const tex = new THREE.CanvasTexture(c)
  tex.needsUpdate = true
  return tex
}
```

- [ ] **Step 2: Build to verify it compiles (with three.js resolved)**

Run: `mix esbuild sea`
Expected: exits 0, no resolution errors (three.js imported successfully).

- [ ] **Step 3: Commit**

```bash
git add assets/js/sea/scene.js
git commit -m "feat: toon ocean scene with islands and flag-sail boats"
```

---

## Task 8: `controls.js` — keyboard + touch steering

Produces a shared input state the render loop reads each frame.

**Files:**
- Create: `assets/js/sea/controls.js`

- [ ] **Step 1: Implement**

Create `assets/js/sea/controls.js`:

```javascript
// Steering input for the local boat. `state.throttle` is 0..1 forward,
// `state.turn` is -1..1 (left/right), `state.dock` latches true when the dock
// key/button is pressed. Works with keyboard (arrows/WASD + space) and an
// on-screen touch joystick + Dock button injected into `overlay`.

export function createControls(overlay) {
  const state = {throttle: 0, turn: 0, dock: false}
  const keys = new Set()

  const onKey = (down) => (e) => {
    const k = e.key.toLowerCase()
    if (["arrowup", "arrowdown", "arrowleft", "arrowright", "w", "a", "s", "d", " "].includes(k)) {
      e.preventDefault()
    }
    if (down) keys.add(k)
    else keys.delete(k)
    if (down && (k === " ")) state.dock = true
  }
  const kd = onKey(true)
  const ku = onKey(false)
  window.addEventListener("keydown", kd)
  window.addEventListener("keyup", ku)

  // Touch controls
  const pad = document.createElement("div")
  pad.className = "sea-touch"
  pad.innerHTML = `
    <div class="sea-stick" data-stick>
      <div class="sea-nub" data-nub></div>
    </div>
    <button class="sea-dock" data-dock type="button">Dock</button>`
  overlay.appendChild(pad)

  const stick = pad.querySelector("[data-stick]")
  const nub = pad.querySelector("[data-nub]")
  let touchId = null

  const setFromTouch = (t) => {
    const r = stick.getBoundingClientRect()
    const cx = r.left + r.width / 2
    const cy = r.top + r.height / 2
    let dx = (t.clientX - cx) / (r.width / 2)
    let dy = (t.clientY - cy) / (r.height / 2)
    dx = Math.max(-1, Math.min(1, dx))
    dy = Math.max(-1, Math.min(1, dy))
    nub.style.transform = `translate(${dx * 34}px, ${dy * 34}px)`
    state.turn = dx
    state.throttle = Math.max(0, -dy)
  }
  const resetTouch = () => {
    touchId = null
    nub.style.transform = "translate(0,0)"
    state.turn = 0
    state.throttle = 0
  }
  stick.addEventListener("touchstart", (e) => {
    touchId = e.changedTouches[0].identifier
    setFromTouch(e.changedTouches[0])
    e.preventDefault()
  }, {passive: false})
  stick.addEventListener("touchmove", (e) => {
    for (const t of e.changedTouches) if (t.identifier === touchId) setFromTouch(t)
    e.preventDefault()
  }, {passive: false})
  stick.addEventListener("touchend", resetTouch)
  stick.addEventListener("touchcancel", resetTouch)
  pad.querySelector("[data-dock]").addEventListener("click", () => (state.dock = true))

  // Fold keyboard into the state each time it's read.
  const read = () => {
    let turn = 0
    let throttle = 0
    if (keys.has("arrowleft") || keys.has("a")) turn -= 1
    if (keys.has("arrowright") || keys.has("d")) turn += 1
    if (keys.has("arrowup") || keys.has("w")) throttle += 1
    if (keys.has("arrowdown") || keys.has("s")) throttle -= 0.4
    // Keyboard overrides only when actually pressed; else keep touch values.
    if (turn !== 0) state.turn = turn
    if (throttle !== 0) state.throttle = Math.max(0, throttle)
    return state
  }

  const destroy = () => {
    window.removeEventListener("keydown", kd)
    window.removeEventListener("keyup", ku)
    if (pad.parentNode) pad.parentNode.removeChild(pad)
  }

  return {read, state, destroy}
}
```

- [ ] **Step 2: Add touch-control styles**

In `assets/css/app.css`, append:

```css
/* Sea easter-egg touch controls (only visible inside the 3D overlay). */
.sea-touch { position: absolute; inset: auto 0 0 0; display: flex;
  justify-content: space-between; align-items: flex-end;
  padding: 24px; pointer-events: none; }
.sea-touch > * { pointer-events: auto; }
.sea-stick { width: 96px; height: 96px; border: 2px solid var(--color-ink);
  background: rgba(238,240,236,.5); position: relative; touch-action: none; }
.sea-nub { width: 40px; height: 40px; background: var(--color-lime);
  border: 2px solid var(--color-ink); position: absolute; left: 26px; top: 26px; }
.sea-dock { border: 2px solid var(--color-ink); background: var(--color-lime);
  color: var(--on-lime); font-weight: 700; text-transform: uppercase;
  letter-spacing: .08em; padding: 12px 18px; font-size: 13px; }
@media (hover: hover) and (pointer: fine) { .sea-touch { display: none; } }
```

- [ ] **Step 3: Build to verify**

Run: `mix esbuild sea && mix tailwind blog`
Expected: both exit 0.

- [ ] **Step 4: Commit**

```bash
git add assets/js/sea/controls.js assets/css/app.css
git commit -m "feat: keyboard + touch steering for the sea"
```

---

## Task 9: `net.js` — channel roster, positions, interpolation

**Files:**
- Create: `assets/js/sea/net.js`

- [ ] **Step 1: Implement**

Create `assets/js/sea/net.js`:

```javascript
import {Socket} from "phoenix"

// Owns the SeaChannel connection. Exposes the current roster (all visitors) and
// a map of live sailor positions (interpolated toward the latest broadcast).
export class SeaNet {
  constructor(sailorId) {
    this.sailorId = sailorId
    this.roster = [] // [{id, path, flag}]
    this.remote = new Map() // id -> {x, z, h, tx, tz, th}  (t* = target)
    this.onRoster = null
    this._lastSent = 0

    const token = document
      .querySelector("meta[name='csrf-token']")
      .getAttribute("content")
    this.socket = new Socket("/socket", {params: {_csrf_token: token}})
    this.socket.connect()
    this.channel = this.socket.channel("sea:ocean", {sailor_id: sailorId})

    this.channel.on("roster", ({sailors}) => {
      this.roster = sailors
      if (this.onRoster) this.onRoster(sailors)
    })
    this.channel.on("pos", ({id, x, z, h}) => {
      if (id === this.sailorId) return
      const cur = this.remote.get(id) || {x, z, h, tx: x, tz: z, th: h}
      cur.tx = x
      cur.tz = z
      cur.th = h
      this.remote.set(id, cur)
    })
    this.channel.on("gone", ({id}) => this.remote.delete(id))
    this.channel.join()
  }

  // Throttle outgoing positions to ~12 Hz.
  sendPos(x, z, h) {
    const now = performance.now()
    if (now - this._lastSent < 80) return
    this._lastSent = now
    this.channel.push("pos", {x, z, h})
  }

  // Ease live boats toward their latest target; call each frame.
  interpolate() {
    for (const p of this.remote.values()) {
      p.x += (p.tx - p.x) * 0.2
      p.z += (p.tz - p.z) * 0.2
      p.h += angleDelta(p.h, p.th) * 0.2
    }
  }

  destroy() {
    try { this.channel.leave() } catch (_) {}
    try { this.socket.disconnect() } catch (_) {}
  }
}

function angleDelta(a, b) {
  let d = b - a
  while (d > Math.PI) d -= 2 * Math.PI
  while (d < -Math.PI) d += 2 * Math.PI
  return d
}
```

- [ ] **Step 2: Build to verify**

Run: `mix esbuild sea`
Expected: exits 0 (phoenix `Socket` resolves — it's already an assets dep via `phoenix`).

- [ ] **Step 3: Commit**

```bash
git add assets/js/sea/net.js
git commit -m "feat: sea channel client with position interpolation"
```

---

## Task 10: `index.js` — orchestrator, render loop, docking

Wires scene + controls + net together: renders islands, your boat, other visitors (anchored readers at their island, live sailors at their broadcast position), the approaching-island title banner, and docking → navigate + exit Sea.

**Files:**
- Modify: `assets/js/sea/index.js` (replace the stub)

- [ ] **Step 1: Implement**

Replace `assets/js/sea/index.js` with:

```javascript
import {SeaScene, flagTexture} from "./scene.js"
import {createControls} from "./controls.js"
import {SeaNet} from "./net.js"
import {nearestDockable, nearestIsland} from "./world.js"

let active = null

export function startSea({el, sailorId, islands}) {
  if (active) return
  active = new Sea(el, sailorId, islands)
}

export function stopSea() {
  if (active) {
    active.destroy()
    active = null
  }
}

class Sea {
  constructor(el, sailorId, islands) {
    this.el = el
    this.sailorId = sailorId
    this.islands = islands
    this.islandsByPath = new Map(islands.map((i) => [i.path, i]))

    this.scene = new SeaScene(el)
    for (const isl of islands) this.scene.addIsland(isl)

    // Local boat starts at the harbor.
    const harbor = this.islandsByPath.get("/") || {x: 0, z: 0}
    this.pos = {x: harbor.x, z: harbor.z + 20, h: Math.PI}
    this.selfBoat = this.scene.makeBoat(flagTexture("🏴"), true)

    this.controls = createControls(el)
    this.net = new SeaNet(sailorId)
    this.readerBoats = new Map() // id -> {group}
    this.remoteBoats = new Map() // id -> {group}

    this.banner = document.createElement("div")
    this.banner.className = "sea-banner"
    el.appendChild(this.banner)

    this.hint = document.createElement("div")
    this.hint.className = "sea-hint"
    this.hint.textContent = "Arrows / WASD to sail · Space to dock · toggle theme to leave"
    el.appendChild(this.hint)

    this.t = 0
    this.running = true
    this.loop = this.loop.bind(this)
    requestAnimationFrame(this.loop)
  }

  loop() {
    if (!this.running) return
    this.t += 0.016

    const input = this.controls.read()
    // Integrate simple boat motion.
    this.pos.h -= input.turn * 0.03
    const speed = input.throttle * 0.6
    this.pos.x += Math.sin(this.pos.h) * speed
    this.pos.z += Math.cos(this.pos.h) * speed

    this.selfBoat.position.set(this.pos.x, 0, this.pos.z)
    this.selfBoat.rotation.y = this.pos.h

    this.net.sendPos(
      round(this.pos.x),
      round(this.pos.z),
      round(this.pos.h)
    )
    this.net.interpolate()

    this.syncOtherBoats()
    this.updateBanner()

    if (input.dock) {
      input.dock = false
      const isl = nearestDockable(this.pos.x, this.pos.z, this.islands)
      if (isl) this.dockTo(isl)
    }

    this.scene.animateWater(this.t)
    this.scene.chase(this.pos, this.pos.h)
    this.scene.render()
    requestAnimationFrame(this.loop)
  }

  // Live sailors (from net.remote). A sailor id that is also in the roster is
  // still drawn from its live position; the roster only anchors *readers*.
  syncOtherBoats() {
    const liveIds = new Set()
    for (const [id, p] of this.net.remote) {
      if (id === this.sailorId) continue
      liveIds.add(id)
      let b = this.remoteBoats.get(id)
      if (!b) {
        b = this.scene.makeBoat(flagTexture(this.flagFor(id)), false)
        this.remoteBoats.set(id, b)
      }
      b.position.set(p.x, 0, p.z)
      b.rotation.y = p.h
    }
    for (const [id, b] of this.remoteBoats) {
      if (!liveIds.has(id)) {
        this.scene.removeBoat(b)
        this.remoteBoats.delete(id)
      }
    }

    // Anchored reader boats: everyone in the roster who is NOT sailing live and
    // is not us. Bob them gently at their island.
    const anchored = new Set()
    for (const s of this.net.roster) {
      if (s.id === this.sailorId || liveIds.has(s.id)) continue
      const isl = this.islandsByPath.get(s.path)
      if (!isl) continue
      anchored.add(s.id)
      let b = this.readerBoats.get(s.id)
      if (!b) {
        b = this.scene.makeBoat(flagTexture(s.flag), false)
        this.readerBoats.set(s.id, b)
      }
      const bob = Math.sin(this.t * 1.5 + hash(s.id)) * 0.4
      b.position.set(isl.x + 10, bob, isl.z + 10)
      b.rotation.y = hash(s.id)
    }
    for (const [id, b] of this.readerBoats) {
      if (!anchored.has(id)) {
        this.scene.removeBoat(b)
        this.readerBoats.delete(id)
      }
    }
  }

  flagFor(id) {
    const s = this.net.roster.find((r) => r.id === id)
    return s ? s.flag : "🏳️"
  }

  updateBanner() {
    const near = nearestIsland(this.pos.x, this.pos.z, this.islands)
    if (near && near.distance < 40) {
      this.banner.textContent =
        near.distance < 9 ? `${near.island.title} — press Space to dock` : near.island.title
      this.banner.style.opacity = "1"
    } else {
      this.banner.style.opacity = "0"
    }
  }

  dockTo(island) {
    // Leaving Sea mode: restore the previous light/dark theme, then navigate.
    const prev = localStorage.themePrev || "light"
    localStorage.theme = prev
    document.documentElement.dataset.theme = prev
    document.dispatchEvent(new CustomEvent("theme:changed", {detail: {theme: prev}}))
    window.location.href = island.path
  }

  destroy() {
    this.running = false
    this.controls.destroy()
    this.net.destroy()
    this.scene.dispose()
    if (this.banner.parentNode) this.banner.remove()
    if (this.hint.parentNode) this.hint.remove()
  }
}

function round(n) {
  return Math.round(n * 100) / 100
}

function hash(s) {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 6283
  return h / 1000
}
```

- [ ] **Step 2: Remember the previous theme when entering Sea**

So docking can restore Light/Dark, record the outgoing theme in the `ThemeToggle.apply` in `assets/js/app.js`. Update `apply(theme)` to stash the prior theme:

```javascript
    apply(theme) {
      const prev = document.documentElement.dataset.theme
      if (prev && prev !== "sea") localStorage.themePrev = prev
      document.documentElement.dataset.theme = theme
      localStorage.theme = theme
      this.el.textContent = this.labelFor(theme)
      document.dispatchEvent(new CustomEvent("theme:changed", {detail: {theme}}))
    },
```

- [ ] **Step 3: Add banner + hint styles**

Append to `assets/css/app.css`:

```css
.sea-banner { position: absolute; top: 8%; left: 0; right: 0; text-align: center;
  font-family: "Space Grotesk", system-ui, sans-serif; font-weight: 700;
  font-size: clamp(20px, 4vw, 40px); color: var(--color-ink);
  text-transform: uppercase; letter-spacing: -0.01em; pointer-events: none;
  opacity: 0; transition: opacity 200ms ease; }
.sea-hint { position: absolute; top: 16px; left: 0; right: 0; text-align: center;
  font-size: 12px; letter-spacing: .06em; text-transform: uppercase;
  color: var(--color-ink-2); pointer-events: none; }
```

- [ ] **Step 4: Build everything**

Run: `mix assets.build`
Expected: exits 0 (tailwind + both esbuild profiles).

- [ ] **Step 5: Manual end-to-end verification** (use the `/run` skill or `mix phx.server`)

Open two browser windows:
1. **Window A** — go to a blog post and stay (a "reader"). Leave theme on Light/Dark.
2. **Window B** — toggle theme to **Sea**. Confirm: a 3D ocean with lime islands appears; your boat spawns near the harbor; arrows/WASD sail it with a chase cam; nearing an island floats its title; there is a bobbing reader-boat flying a flag at Window A's post island.
3. In Window B sail into that island and press **Space** → confirm you navigate to the post and drop out of Sea mode into normal reading.
4. Open a **Window C** also in Sea mode and confirm B and C see each other's boats move live (not just anchored).

Fix any issues before committing. Verify normal pages (Light/Dark) are visually unchanged and that `app.js` still doesn't contain three.js (`grep -c "three" priv/static/assets/js/app.js` → `0`).

- [ ] **Step 6: Commit**

```bash
git add assets/js/sea/index.js assets/js/app.js assets/css/app.css
git commit -m "feat: sea render loop, live + anchored boats, docking to posts"
```

---

## Task 11: Polish + guardrails

**Files:**
- Modify: `assets/js/sea/index.js`, `assets/css/app.css` as needed

- [ ] **Step 1: Cap remote boat count and guard missing data**

In `syncOtherBoats` (index.js), guard against a roster entry with a null `path` or `flag` (already handled by the `if (!isl) continue`), and cap total drawn boats to keep mobile smooth. At the top of `syncOtherBoats`, add:

```javascript
    const MAX_BOATS = 60
    let drawn = 0
```

and in both creation branches, before creating a boat, add `if (drawn++ > MAX_BOATS) break` inside the respective loops (place the `break` guard as the first statement of each `for` body, after the `continue` filters).

- [ ] **Step 2: Add an explicit "Leave" affordance**

Append to `assets/js/sea/index.js` constructor (after `this.hint` setup):

```javascript
    this.leaveBtn = document.createElement("button")
    this.leaveBtn.className = "sea-leave"
    this.leaveBtn.textContent = "Leave the sea"
    this.leaveBtn.addEventListener("click", () => {
      const prev = localStorage.themePrev || "light"
      localStorage.theme = prev
      document.documentElement.dataset.theme = prev
      document.dispatchEvent(new CustomEvent("theme:changed", {detail: {theme: prev}}))
    })
    el.appendChild(this.leaveBtn)
```

and in `destroy()` add `if (this.leaveBtn.parentNode) this.leaveBtn.remove()`.

Append style to `assets/css/app.css`:

```css
.sea-leave { position: absolute; top: 16px; right: 16px; border: 2px solid var(--color-ink);
  background: var(--color-paper); color: var(--color-ink); font-weight: 700;
  text-transform: uppercase; letter-spacing: .08em; font-size: 12px; padding: 8px 12px; }
```

- [ ] **Step 3: Build + manual smoke test**

Run: `mix assets.build`
Expected: exits 0. In the browser, confirm the Leave button exits Sea mode back to the prior theme, and that with several tabs open the scene stays smooth.

- [ ] **Step 4: Full test suite**

Run: `mix test`
Expected: PASS (all green).

- [ ] **Step 5: Commit**

```bash
git add assets/js/sea/index.js assets/css/app.css
git commit -m "polish: leave affordance and boat-count guardrails for the sea"
```

---

## Self-Review Notes (for the implementer)

- **Spec coverage:** motif=sailing (scene.js); islands=every page (SeaWorld, Task 2); readers anchored + sailors live (index.js `syncOtherBoats`, Task 10); entry=third theme state (Task 5); docking opens post (index.js `dockTo`); flag sails (scene.js `flagTexture` + channel `flag/1`); toon/cel look (scene.js outline + MeshToonMaterial); lazy-loaded three.js (Task 1). All present.
- **Identity correlation:** `sailor_id` is generated once (root.html.heex), sent as a LiveView connect param (app.js) → presence meta (Task 3) and as the channel join param (net.js) → position id (Task 4). Roster ids and position ids therefore match, so `syncOtherBoats` reconciles correctly.
- **No bundle regression:** verified by the `grep -c "three" …app.js` → `0` checks in Tasks 1, 5, 10.
```
