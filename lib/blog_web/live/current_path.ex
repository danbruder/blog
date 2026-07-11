defmodule BlogWeb.CurrentPath do
  @moduledoc """
  LiveView `on_mount` hook that assigns `:current_path` from the request URI so
  the root layout can render a correct canonical / og:url for each page.
  """
  import Phoenix.LiveView, only: [attach_hook: 4]
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     attach_hook(socket, :current_path, :handle_params, fn _params, uri, socket ->
       {:cont, assign(socket, :current_path, URI.parse(uri).path)}
     end)}
  end
end
