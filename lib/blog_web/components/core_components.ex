defmodule BlogWeb.CoreComponents do
  @moduledoc """
  A small set of UI building blocks used by the admin CMS forms.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr(:flash, :map, default: %{})
  attr(:id, :string, default: "flash-group")

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  attr(:id, :string, default: nil)
  attr(:flash, :map, default: %{})
  attr(:kind, :atom, values: [:info, :error])
  attr(:rest, :global)

  def flash(assigns) do
    assigns = assign_new(assigns, :msg, fn -> Phoenix.Flash.get(assigns.flash, assigns.kind) end)

    ~H"""
    <div
      :if={@msg}
      id={@id || "flash-#{@kind}"}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> JS.hide()}
      role="alert"
      class={[
        "fixed top-2 right-2 z-50 w-80 rounded-lg p-3 text-sm shadow-lg border",
        @kind == :info && "bg-zinc-800 text-sky-200 border-sky-900",
        @kind == :error && "bg-zinc-800 text-orange-200 border-orange-900"
      ]}
      {@rest}
    >
      {@msg}
    </div>
    """
  end

  attr(:for, :any, required: true, doc: "the datastructure for the form")
  attr(:rest, :global, include: ~w(autocomplete name rel action enctype method novalidate))

  slot(:inner_block, required: true)
  slot(:actions)

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} {@rest}>
      {render_slot(@inner_block, f)}
      <div :for={action <- @actions} class="mt-6 flex items-center gap-4">
        {render_slot(action, f)}
      </div>
    </.form>
    """
  end

  attr(:type, :string, default: "button")
  attr(:class, :string, default: nil)
  attr(:rest, :global, include: ~w(disabled form name value))
  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "rounded-lg bg-sky-800 hover:bg-sky-700 px-3 py-2 text-sm font-semibold text-sky-100 border border-sky-700 transition-colors",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)

  attr(:type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)
  )

  attr(:field, Phoenix.HTML.FormField, doc: "a form field struct, for example: @form[:email]")
  attr(:errors, :list, default: [])
  attr(:checked, :boolean, doc: "the checked flag for checkboxes")
  attr(:options, :list, doc: "the options for select")
  attr(:rows, :string, default: "6")

  attr(:rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)
  )

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-4">
      <label class="flex items-center gap-2 text-sm text-zinc-300">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-zinc-600 bg-zinc-800 text-sky-600"
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-4">
      <.label :if={@label} for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class="mt-1 block w-full rounded-lg bg-zinc-800 border-zinc-600 text-zinc-100 focus:border-sky-600 focus:ring-sky-600"
        {@rest}
      >
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-4">
      <.label :if={@label} for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        rows={@rows}
        class="mt-1 block w-full rounded-lg bg-zinc-800 border-zinc-600 text-zinc-100 font-mono text-sm focus:border-sky-600 focus:ring-sky-600"
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="mb-4">
      <.label :if={@label} for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class="mt-1 block w-full rounded-lg bg-zinc-800 border-zinc-600 text-zinc-100 focus:border-sky-600 focus:ring-sky-600"
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  attr(:for, :string, required: true)
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold text-zinc-300 mb-1">
      {render_slot(@inner_block)}
    </label>
    """
  end

  slot(:inner_block, required: true)

  def error(assigns) do
    ~H"""
    <p class="mt-1 text-sm text-orange-300">
      {render_slot(@inner_block)}
    </p>
    """
  end

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
