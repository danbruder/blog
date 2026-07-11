defmodule Blog.GeoIPTest do
  use ExUnit.Case, async: true

  alias Blog.GeoIP

  test "returns nil for a nil ip" do
    assert GeoIP.country_for_ip(nil) == nil
  end

  test "returns nil without making a network call when geoip is disabled" do
    # config/test.exs sets :geoip_enabled to false so this never hits the network.
    assert GeoIP.country_for_ip("8.8.8.8") == nil
  end
end
