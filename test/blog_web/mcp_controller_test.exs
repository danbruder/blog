defmodule BlogWeb.MCPControllerTest do
  use BlogWeb.ConnCase, async: true

  alias Blog.Content

  defp authed(conn) do
    token = Application.fetch_env!(:blog, :mcp_api_token)
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  defp rpc(conn, method, params \\ %{}, id \\ 1) do
    body = %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
    post(conn |> authed() |> put_req_header("content-type", "application/json"), ~p"/mcp", body)
  end

  test "rejects a request with no Authorization header", %{conn: conn} do
    conn =
      post(
        put_req_header(conn, "content-type", "application/json"),
        ~p"/mcp",
        %{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"}
      )

    assert conn.status == 401
    assert json_response(conn, 401)["error"]["message"] == "Unauthorized"
  end

  test "rejects a request with the wrong token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer wrong")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/mcp", %{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"})

    assert conn.status == 401
  end

  test "rejects every request when MCP_API_TOKEN isn't configured (the app still boots)", %{
    conn: conn
  } do
    original = Application.get_env(:blog, :mcp_api_token)
    on_exit(fn -> Application.put_env(:blog, :mcp_api_token, original) end)
    Application.put_env(:blog, :mcp_api_token, nil)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{original}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/mcp", %{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"})

    assert conn.status == 401
  end

  test "a notification (no id) gets a 202 with no body", %{conn: conn} do
    conn =
      conn
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/mcp", %{"jsonrpc" => "2.0", "method" => "notifications/initialized"})

    assert conn.status == 202
    assert conn.resp_body == ""
  end

  test "initialize returns protocol version, capabilities, and server info", %{conn: conn} do
    conn = rpc(conn, "initialize")
    result = json_response(conn, 200)["result"]

    assert result["protocolVersion"]
    assert result["capabilities"] == %{"tools" => %{}}
    assert result["serverInfo"]["name"] == "danbruder-blog"
  end

  test "ping returns an empty result", %{conn: conn} do
    conn = rpc(conn, "ping")
    assert json_response(conn, 200)["result"] == %{}
  end

  test "tools/list returns the tool schemas", %{conn: conn} do
    conn = rpc(conn, "tools/list")
    tools = json_response(conn, 200)["result"]["tools"]

    assert Enum.any?(tools, &(&1["name"] == "create_post"))
  end

  test "an unknown method returns a JSON-RPC error", %{conn: conn} do
    conn = rpc(conn, "not/a/method")
    error = json_response(conn, 200)["error"]

    assert error["code"] == -32_601
    assert error["message"] =~ "Method not found"
  end

  test "tools/call round-trips create_post, get_post, and publish_post", %{conn: conn} do
    create_conn =
      rpc(conn, "tools/call", %{"name" => "create_post", "arguments" => %{"title" => "Hi there"}})

    created = decode_tool_result(create_conn)
    assert created["published"] == false
    assert created["slug"] == "hi-there"

    post_id = created["id"]

    publish_conn =
      rpc(conn, "tools/call", %{"name" => "publish_post", "arguments" => %{"id" => post_id}})

    published = decode_tool_result(publish_conn)
    assert published["published"] == true

    assert Content.get_post(post_id).published == true
  end

  test "tools/call reports a tool-level error via isError, not a JSON-RPC error", %{conn: conn} do
    conn = rpc(conn, "tools/call", %{"name" => "get_post", "arguments" => %{"slug" => "nope"}})
    result = json_response(conn, 200)["result"]

    assert result["isError"] == true
    assert hd(result["content"])["text"] =~ "no post with slug"
  end

  defp decode_tool_result(conn) do
    conn
    |> json_response(200)
    |> get_in(["result", "content"])
    |> hd()
    |> Map.fetch!("text")
    |> Jason.decode!()
  end
end
