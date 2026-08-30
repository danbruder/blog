defmodule BlogWeb.MCPController do
  @moduledoc """
  A minimal MCP (Model Context Protocol) server over the "Streamable HTTP"
  transport: a single `POST /mcp` endpoint speaking JSON-RPC 2.0, guarded by
  `BlogWeb.Plugs.MCPAuth`. Every response is a plain JSON object (no SSE) --
  this server has no long-running or multi-message tool calls, so a
  streaming response body would add complexity without buying anything.

  Tool schemas and behavior live in `Blog.MCP`; this module only handles the
  JSON-RPC envelope (requests vs. notifications, method routing, error
  shapes).
  """

  use BlogWeb, :controller

  alias Blog.MCP

  def handle(conn, params) do
    case Map.get(params, "id") do
      nil -> send_resp(conn, 202, "")
      id -> handle_request(conn, id, params)
    end
  end

  defp handle_request(conn, id, %{"method" => method} = params) when is_binary(method) do
    args = Map.get(params, "params", %{})

    case dispatch(method, args) do
      {:ok, result} ->
        json(conn, %{jsonrpc: "2.0", id: id, result: result})

      {:error, code, message} ->
        json(conn, %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}})
    end
  end

  defp handle_request(conn, id, _params) do
    json(conn, %{jsonrpc: "2.0", id: id, error: %{code: -32_600, message: "Invalid Request"}})
  end

  defp dispatch("initialize", _args) do
    {:ok,
     %{
       protocolVersion: MCP.protocol_version(),
       capabilities: %{tools: %{}},
       serverInfo: MCP.server_info()
     }}
  end

  defp dispatch("ping", _args), do: {:ok, %{}}

  defp dispatch("tools/list", _args), do: {:ok, %{tools: MCP.tools()}}

  defp dispatch("tools/call", %{"name" => name} = args) when is_binary(name) do
    arguments = Map.get(args, "arguments", %{})

    case MCP.call_tool(name, arguments) do
      {:ok, result} ->
        {:ok, %{content: [%{type: "text", text: Jason.encode!(result)}]}}

      {:error, message} ->
        {:ok, %{content: [%{type: "text", text: to_string(message)}], isError: true}}
    end
  end

  defp dispatch("tools/call", _args),
    do: {:error, -32_602, "Invalid params: \"name\" is required"}

  defp dispatch(other, _args), do: {:error, -32_601, "Method not found: #{other}"}
end
