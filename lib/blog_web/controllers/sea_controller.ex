defmodule BlogWeb.SeaController do
  @moduledoc """
  Serves the sailing-world island list as JSON for the Sea easter egg. Kept
  out of the normal page HTML (rather than embedded in a data attribute) so
  every page load doesn't ship every post/note title — the Sea hook fetches
  this only when Sea mode actually activates.
  """

  use BlogWeb, :controller

  alias BlogWeb.SeaWorld

  def islands(conn, _params) do
    json(conn, %{islands: SeaWorld.islands()})
  end
end
