defmodule BlogWeb.Admin.PostFormLive do
  use BlogWeb, :live_view

  alias Blog.Content
  alias Blog.Content.Post

  @impl true
  def mount(params, _session, socket) do
    post =
      case socket.assigns.live_action do
        :new -> %Post{kind: "post", published: true, published_at: Date.utc_today()}
        :edit -> Content.get_post!(params["id"])
      end

    changeset = Content.change_post(post)

    {:ok,
     socket
     |> assign(
       page_title: if(socket.assigns.live_action == :new, do: "New post", else: "Edit post"),
       post: post
     )
     |> assign_form(changeset)
     |> assign(:preview_html, render_preview(post.body))}
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
     |> assign(:preview_html, render_preview(post_params["body"]))}
  end

  def handle_event("slugify", _params, socket) do
    current_params = socket.assigns.form.params
    title = Ecto.Changeset.get_field(socket.assigns.form.source, :title) || ""
    slug = slugify(title)

    changeset =
      Content.change_post(socket.assigns.post, Map.put(current_params, "slug", slug))

    {:noreply, assign_form(socket, changeset)}
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

  defp assign_form(socket, changeset) do
    assign(socket, form: to_form(changeset))
  end

  defp render_preview(body), do: Content.render_markdown(body)

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

          <div class="grid gap-6 lg:grid-cols-2">
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
