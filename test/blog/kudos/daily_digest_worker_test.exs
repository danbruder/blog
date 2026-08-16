defmodule Blog.Kudos.DailyDigestWorkerTest do
  use Blog.DataCase, async: false

  alias Blog.Kudos.DailyDigestWorker

  test "perform/1 runs the digest for today without crashing" do
    # Whether any kudos actually landed in "today"'s real wall-clock window
    # depends on what else the suite did before this test runs, so either
    # outcome is legitimate here -- what this guards against is a typo'd
    # module/function reference or a raise. Blog.KudosTest covers the
    # branch logic (:no_kudos vs. an actual send) with controlled windows.
    assert DailyDigestWorker.perform(%Oban.Job{}) in [:ok, {:error, :missing_api_key}]
  end
end
