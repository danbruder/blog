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
    title = Ecto.Changeset.get_field(socket.assigns.form.source, :title) || ""
    slug = slugify(title)

    changeset = Content.change_post(socket.assigns.post, %{"slug" => slug})
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

  defp render_preview(nil), do: ""

  defp render_preview(body) do
    case Earmark.as_html(body) do
      {:ok, html, _} -> html
      {:error, html, _} -> html
    end
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
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-5xl">
        <h1 class="text-3xl text-sky-200 mb-6">{@page_title}</h1>

        <.simple_form for={@form} id="post-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:title]} label="Title" />

          <div class="flex items-end gap-3">
            <div class="flex-grow">
              <.input field={@form[:slug]} label="Slug" />
            </div>
            <.button type="button" phx-click="slugify" class="mb-4">From title</.button>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:kind]}
              type="select"
              label="Kind"
              options={[{"Post", "post"}, {"Note", "note"}, {"Page", "page"}]}
            />
            <.input field={@form[:published_at]} type="date" label="Published date" />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:category]} label="Category" />
            <.input field={@form[:tags]} label="Tags (comma separated)" />
          </div>

          <.input field={@form[:published]} type="checkbox" label="Published (visible on site)" />

          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:body]} type="textarea" label="Body (Markdown)" rows="24" />
            <div>
              <.label for="preview">Preview</.label>
              <div
                id="preview"
                class="markdown-content mt-1 h-[calc(24*1.5rem+2rem)] overflow-y-auto rounded-lg border border-zinc-700 bg-zinc-800 px-4"
              >
                {Phoenix.HTML.raw(@preview_html)}
              </div>
            </div>
          </div>

          <:actions>
            <.button type="submit">Save</.button>
            <.link navigate={~p"/admin"} class="text-sm text-zinc-400 underline">Cancel</.link>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end
