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

  defp valid_token?(token) do
    configured = Application.fetch_env!(:blog, :mcp_api_token)
    Plug.Crypto.secure_compare(token, configured)
  end
end
