defmodule Blog.Resend do
  @moduledoc """
  Minimal client for the Resend (https://resend.com) transactional email
  API, currently used only by `Blog.Kudos` for the daily kudos digest.

  Sends requests directly over `:httpc` (mirroring `Blog.GeoIP`'s approach
  to calling an external HTTP API) rather than pulling in a full HTTP
  client stack for what's currently a single outbound email a day.
  """

  require Logger

  @endpoint ~c"https://api.resend.com/emails"

  @doc """
  Sends an email via Resend. `attrs` must include `:to`, `:subject`, and
  `:html`; `:text` is an optional plain-text fallback.

  Returns `:ok` on success. Returns `{:error, :missing_api_key}` or
  `{:error, :missing_from_address}` if `config :blog, Blog.Resend` isn't
  set (see `config/runtime.exs` -- `RESEND_API_KEY` / `RESEND_FROM_EMAIL`),
  or `{:error, reason}` if the request itself fails. Never raises, so a
  misconfigured or unreachable Resend never crashes the caller -- callers
  that run as an Oban job get a retry for free instead.
  """
  def send_email(%{to: to, subject: subject, html: html} = attrs)
      when is_binary(to) and is_binary(subject) and is_binary(html) do
    with {:ok, api_key} <- fetch_config(:api_key, :missing_api_key),
         {:ok, from} <- fetch_config(:from, :missing_from_address) do
      body = %{from: from, to: [to], subject: subject, html: html}
      body = if text = attrs[:text], do: Map.put(body, :text, text), else: body

      request(api_key, Jason.encode!(body))
    end
  end

  defp fetch_config(key, error) do
    case Application.get_env(:blog, __MODULE__, [])[key] do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, error}
    end
  end

  defp request(api_key, json_body) do
    headers = [
      {~c"authorization", ~c"Bearer #{api_key}"},
      {~c"content-type", ~c"application/json"}
    ]

    ssl_opts = [
      verify: :verify_peer,
      cacertfile: CAStore.file_path(),
      depth: 3,
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    http_request = {@endpoint, headers, ~c"application/json", json_body}

    case :httpc.request(:post, http_request, [ssl: ssl_opts, timeout: 10_000], []) do
      {:ok, {{_, status, _}, _headers, _body}} when status in 200..299 ->
        :ok

      {:ok, {{_, status, _}, _headers, body}} ->
        Logger.warning("Blog.Resend: send failed with HTTP #{status}: #{body}")
        {:error, {:http_status, status}}

      {:error, reason} ->
        Logger.warning("Blog.Resend: request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
