defmodule BlogWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import BlogWeb.ConnCase

      unquote(BlogWeb.verified_routes())

      @endpoint BlogWeb.Endpoint
    end
  end

  setup tags do
    Blog.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
