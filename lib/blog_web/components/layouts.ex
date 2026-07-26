defmodule BlogWeb.Layouts do
  use BlogWeb, :html

  embed_templates("layouts/*")

  @doc "Zero-pads a small count for the sidebar nav (e.g. 9 -> \"09\")."
  def pad(n) when is_integer(n) and n < 10, do: "0#{n}"
  def pad(n), do: to_string(n)
end
