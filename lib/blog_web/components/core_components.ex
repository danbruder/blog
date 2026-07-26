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
        "fixed right-3 top-3 z-50 w-80 border p-3 text-sm",
        @kind == :info && "border-ink bg-paper text-ink",
        @kind == :error && "border-ink bg-lime text-on-lime"
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
        "border border-ink bg-ink px-[18px] py-[10px] text-[13px] font-semibold tracking-[0.04em] text-paper transition-colors hover:bg-lime hover:text-on-lime",
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
      <label class="flex items-center gap-2 text-sm text-ink-2">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="border-ink bg-paper text-ink focus:ring-lime"
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
        class="mt-1 block w-full border border-ink bg-paper text-ink focus:border-ink focus:ring-lime"
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
        class="mt-1 block w-full border border-ink bg-paper font-mono text-sm text-ink focus:border-ink focus:ring-lime"
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
        class="mt-1 block w-full border border-ink bg-paper text-ink focus:border-ink focus:ring-lime"
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
    <label for={@for} class="label mb-1 block">
      {render_slot(@inner_block)}
    </label>
    """
  end

  slot(:inner_block, required: true)

  def error(assigns) do
    ~H"""
    <p class="mt-1 text-sm">
      <span class="mark">{render_slot(@inner_block)}</span>
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

  @doc """
  A page header in the system v2 grammar: a small uppercase eyebrow (the
  section name), an oversized Space Grotesk title, an optional subtitle, and
  a hairline ink rule beneath. No painted shapes, no fill.
  """
  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block

  def page_hero(assigns) do
    ~H"""
    <header class="border-b border-ink px-6 pb-8 pt-14 sm:px-10 lg:px-14">
      <p class="label mb-[18px]">{@eyebrow}</p>
      <h1 class="max-w-[13em] font-display text-[clamp(40px,6vw,62px)] font-bold leading-[0.94] tracking-[-0.045em] text-ink">
        {@title}
      </h1>
      <p :if={@subtitle} class="mt-5 max-w-[34em] text-[17px] leading-[1.55] text-ink-2">
        {@subtitle}
      </p>
      {render_slot(@inner_block)}
    </header>
    """
  end

  @doc "Standard horizontal + top padding for the body of a page below its header."
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def page_body(assigns) do
    ~H"""
    <div class={["px-6 pt-10 sm:px-10 lg:px-14", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
