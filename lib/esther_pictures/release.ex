defmodule EstherPictures.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :esther_pictures

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Runs priv/repo/seeds.exs against the production database.

  Intended as a one-time step after the first deploy to populate the design's
  default content. NOTE: the seed script resets the content collections
  (clips/craft/ensemble) to defaults, so don't re-run it once real content has
  been edited. User accounts are never touched.
  """
  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          path = Path.join([:code.priv_dir(@app), "repo", "seeds.exs"])
          if File.exists?(path), do: Code.eval_file(path)
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
