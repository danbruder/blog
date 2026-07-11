defmodule BlogWeb.SEO do
  @moduledoc """
  Helpers for the sharing/discoverability `<meta>` tags rendered in the root
  layout. Values come from assigns when a page sets them, with site-level
  fallbacks otherwise.
  """
  use BlogWeb, :verified_routes

  @site_title "Dan Bruder | Engineering Director"
  @default_description "Dan Bruder — engineering director working on making " <>
                         "reality capture easy. Notes on software, engineering " <>
                         "management, and side projects."

  def site_title, do: @site_title

  def title(assigns), do: assigns[:page_title] || @site_title

  def description(assigns), do: assigns[:meta_description] || @default_description

  def canonical_url(assigns) do
    BlogWeb.Endpoint.url() <> (assigns[:current_path] || "/")
  end

  def og_image, do: BlogWeb.Endpoint.url() <> ~p"/images/my-face-new.jpg"
end
