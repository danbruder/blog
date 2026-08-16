defmodule Blog.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 1)
  end

  # `version: 1` (rather than whatever `up` migrated to) so `down` always
  # rolls all the way back, regardless of which version was current when
  # it's run -- see Oban's own migration docs.
  def down do
    Oban.Migration.down(version: 1)
  end
end
