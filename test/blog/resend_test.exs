defmodule Blog.ResendTest do
  use ExUnit.Case, async: true

  alias Blog.Resend

  test "returns an error without making a network call when unconfigured" do
    # config/test.exs doesn't set an api_key/from for Blog.Resend, so this
    # never reaches the network -- same convention as Blog.GeoIPTest. Not
    # exercised here: Blog.Resend's own config being fully absent (this
    # relies on Application.get_env's `[]` default), and the mirror case of
    # `:from` missing while `:api_key` is set -- both go through the same
    # `fetch_config/2` this already covers, and asserting them would mean
    # mutating this global :blog, Blog.Resend config, which races against
    # other async tests (e.g. Blog.KudosTest) that expect it to stay unset.
    assert Resend.send_email(%{to: "reader@example.com", subject: "Hi", html: "<p>Hi</p>"}) ==
             {:error, :missing_api_key}
  end
end
