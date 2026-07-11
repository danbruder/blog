defmodule Blog.GeoIP do
  @moduledoc """
  Best-effort IP -> ISO 3166-1 alpha-2 country code lookup, via the free
  ip-api.com endpoint (no API key required). Results are cached in an ETS
  table for the life of the process, since ip-api.com's free tier is rate
  limited and repeat visitors shouldn't cost another request.
  """

  use GenServer

  @table __MODULE__

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Returns an upcased two-letter country code, or nil if it can't be determined."
  def country_for_ip(nil), do: nil

  def country_for_ip(ip) when is_binary(ip) do
    if Application.get_env(:blog, :geoip_enabled, true) do
      case :ets.lookup(@table, ip) do
        [{^ip, country}] -> country
        [] -> GenServer.call(__MODULE__, {:lookup, ip}, 5_000)
      end
    end
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:lookup, ip}, _from, state) do
    case :ets.lookup(@table, ip) do
      [{^ip, country}] ->
        {:reply, country, state}

      [] ->
        country = fetch(ip)
        :ets.insert(@table, {ip, country})
        {:reply, country, state}
    end
  end

  defp fetch(ip) do
    url = ~c"http://ip-api.com/json/#{ip}?fields=status,countryCode"

    case :httpc.request(:get, {url, []}, [timeout: 2_000, connect_timeout: 2_000], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        parse(body)

      _ ->
        nil
    end
  end

  defp parse(body) do
    case Jason.decode(body) do
      {:ok, %{"status" => "success", "countryCode" => cc}} when byte_size(cc) == 2 -> cc
      _ -> nil
    end
  end
end
