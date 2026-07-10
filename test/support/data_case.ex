defmodule Blog.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Blog.Repo
      import Ecto
      import Ecto.Query
      import Blog.DataCase
    end
  end

  setup tags do
    Blog.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Blog.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
