defmodule BlogWeb.ErrorHTML do
  use BlogWeb, :html

  embed_templates("error_html/*")

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
