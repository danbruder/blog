defmodule BlogWeb.Plugs.MCPAuth do
  @moduledoc """
  Bearer-token auth for the `/mcp` API. Separate from the cookie-session
  `/admin` login (see `BlogWeb.AdminAuth`) since MCP clients are stateless,
  non-browser callers that authenticate with a single long-lived secret
  instead of logging in.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         true <- valid_token?(token) do
      conn
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{
          jsonrpc: "2.0",
          id: nil,
          error: %{code: -32_000, message: "Unauthorized"}
        })
        |> halt()
    end
  end

  # No MCP_API_TOKEN configured means the feature is off -- reject every
  # request rather than comparing against nil (or, worse, treating an unset
  # token as "no auth required").
  defp valid_token?(token) do
    case Application.get_env(:blog, :mcp_api_token) do
      nil -> false
      configured -> Plug.Crypto.secure_compare(token, configured)
    end
  end
end
