defmodule BlogWeb.Admin.PostFormLive do
  use BlogWeb, :live_view

  alias Blog.Content
  alias Blog.Content.Post

  # How often (while there are unsaved changes) the draft gets written to
  # the DB in the background. Keeps writes bounded to a fixed cadence
  # instead of firing on every keystroke.
  @autosave_interval :timer.seconds(30)

  @impl true
  def mount(params, _session, socket) do
    post =
      case socket.assigns.live_action do
        :new -> %Post{kind: "post", published: true, published_at: Date.utc_today()}
        :edit -> Content.get_post!(params["id"])
      end

    changeset = Content.change_post(post)

    socket =
      socket
      |> assign(
        page_title: if(socket.assigns.live_action == :new, do: "New post", else: "Edit post"),
        post: post
      )
      |> assign_form(changeset)
      |> assign(:preview_html, render_preview(post.body))
      |> assign(:dirty, false)
      |> assign(:last_saved_at, nil)

    socket = if connected?(socket), do: schedule_autosave(socket), else: socket

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      socket.assigns.post
      |> Content.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign(:dirty, true)
     |> assign(:preview_html, render_preview(post_params["body"]))}
  end

  def handle_event("slugify", _params, socket) do
    current_params = socket.assigns.form.params
    title = Ecto.Changeset.get_field(socket.assigns.form.source, :title) || ""
    slug = slugify(title)

    changeset =
      Content.change_post(socket.assigns.post, Map.put(current_params, "slug", slug))

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign(:dirty, true)}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.live_action, post_params)
  end

  defp save_post(socket, :new, post_params) do
    case Content.create_post(post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created")
         |> push_navigate(to: ~p"/admin")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_post(socket, :edit, post_params) do
    case Content.update_post(socket.assigns.post, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated")
         |> push_navigate(to: ~p"/admin")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # Ticks every @autosave_interval regardless of activity; only actually
  # writes to the DB when there are unsaved changes, so an idle editor
  # costs nothing.
  @impl true
  def handle_info(:autosave, socket) do
    socket = if socket.assigns.dirty, do: autosave(socket), else: socket
    {:noreply, schedule_autosave(socket)}
  end

  defp schedule_autosave(socket) do
    Process.send_after(self(), :autosave, @autosave_interval)
    socket
  end

  defp autosave(socket) do
    post_params = socket.assigns.form.params

    changeset =
      socket.assigns.post
      |> Content.change_post(post_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      case persist_draft(socket, post_params) do
        {:ok, post} ->
          socket
          |> assign(:post, post)
          |> assign(:dirty, false)
          |> assign(:last_saved_at, DateTime.utc_now())
          |> promote_new_draft(post)

        # Leave :dirty so the next tick retries — e.g. a slug collision
        # the writer hasn't noticed yet.
        {:error, _changeset} ->
          socket
      end
    else
      socket
    end
  end

  defp persist_draft(%{assigns: %{live_action: :new}}, post_params),
    do: Content.create_post(post_params)

  defp persist_draft(%{assigns: %{live_action: :edit, post: post}}, post_params),
    do: Content.update_post(post, post_params)

  # A brand-new post's first autosave creates the row; swap the URL and
  # live_action over to :edit so it keeps updating that same row instead
  # of creating a new one on every subsequent tick (or on manual Save).
  defp promote_new_draft(%{assigns: %{live_action: :new}} = socket, post) do
    socket
    |> assign(:live_action, :edit)
    |> assign(:page_title, "Edit post")
    |> push_patch(to: ~p"/admin/posts/#{post.id}/edit")
  end

  defp promote_new_draft(socket, _post), do: socket

  defp assign_form(socket, changeset) do
    assign(socket, form: to_form(changeset))
  end

  defp render_preview(body), do: Content.render_markdown(body)

  defp autosave_status(true, _last_saved_at), do: "Unsaved changes"
  defp autosave_status(false, nil), do: nil
  defp autosave_status(false, last_saved_at) do
    "Autosaved #{Calendar.strftime(last_saved_at, "%H:%M UTC")}"
  end

  # Purely client-side: no server round-trip needed to enter/exit the
  # focused writing mode, so the toggle stays instant.
  defp toggle_fullscreen(js \\ %JS{}) do
    js
    |> JS.add_class("is-fullscreen", to: "#editor-pane")
    |> JS.add_class("hidden", to: "#fullscreen-toggle")
    |> JS.remove_class("hidden", to: "#fullscreen-exit")
    |> JS.add_class("overflow-hidden", to: "body")
  end

  defp exit_fullscreen(js \\ %JS{}) do
    js
    |> JS.remove_class("is-fullscreen", to: "#editor-pane")
    |> JS.remove_class("hidden", to: "#fullscreen-toggle")
    |> JS.add_class("hidden", to: "#fullscreen-exit")
    |> JS.remove_class("overflow-hidden", to: "body")
  end

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_body>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8 flex items-center justify-between gap-4">
          <h1 class="font-display text-[28px] font-bold tracking-[-0.03em] text-ink">
            {@page_title}
          </h1>
          <.link
            navigate={~p"/admin"}
            class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
          >
            &larr; Back to posts
          </.link>
        </div>

        <.simple_form for={@form} id="post-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:title]} label="Title" />

          <div class="flex items-end gap-3">
            <div class="flex-1">
              <.input field={@form[:slug]} label="Slug" />
            </div>
            <.button type="button" phx-click="slugify" class="mb-4 shrink-0">From title</.button>
          </div>

          <div class="grid gap-4 sm:grid-cols-2">
            <.input
              field={@form[:kind]}
              type="select"
              label="Kind"
              options={[{"Post", "post"}, {"Note", "note"}, {"Page", "page"}]}
            />
            <.input field={@form[:published_at]} type="date" label="Published date" />
          </div>

          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={@form[:category]} label="Category" />
            <.input field={@form[:tags]} label="Tags (comma separated)" />
          </div>

          <.input field={@form[:published]} type="checkbox" label="Published (visible on site)" />

          <div class="mb-2 flex items-center justify-end">
            <button
              type="button"
              id="fullscreen-toggle"
              phx-click={toggle_fullscreen()}
              class="border border-ink bg-paper px-3 py-[7px] text-[12px] font-semibold tracking-[0.04em] text-ink-2 transition-colors hover:bg-lime hover:text-on-lime"
            >
              ⤢ Full screen
            </button>
          </div>

          <div
            id="editor-pane"
            class="editor-pane grid gap-6 lg:grid-cols-2"
            phx-window-keydown={exit_fullscreen()}
            phx-key="Escape"
          >
            <button
              type="button"
              id="fullscreen-exit"
              phx-click={exit_fullscreen()}
              class="absolute right-6 top-6 z-10 hidden border border-ink bg-paper px-3 py-[7px] text-[12px] font-semibold tracking-[0.04em] text-ink-2 transition-colors hover:bg-lime hover:text-on-lime"
            >
              ⤢ Exit full screen <span class="text-ink-3">&middot; Esc</span>
            </button>

            <.input field={@form[:body]} type="textarea" label="Body (Markdown)" rows="24" />
            <div>
              <.label for="preview">Preview</.label>
              <div
                id="preview"
                class="markdown-content !mt-1 h-[calc(24*1.5rem+2rem)] overflow-y-auto border border-rule bg-paper-2 px-5 py-4"
              >
                {Phoenix.HTML.raw(@preview_html)}
              </div>
            </div>
          </div>

          <:actions>
            <.button type="submit">Save</.button>
            <span
              :if={status = autosave_status(@dirty, @last_saved_at)}
              class="text-[13px] text-ink-3"
            >
              {status}
            </span>
            <.link
              navigate={~p"/admin"}
              class="text-[13px] text-ink-2 !shadow-[inset_0_-1px_0_var(--color-rule)] hover:!text-ink"
            >
              Cancel
            </.link>
          </:actions>
        </.simple_form>
      </div>
    </.page_body>
    """
  end
end
