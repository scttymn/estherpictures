defmodule EstherPictures.Repo.Migrations.AddHeadshotPathToEnsembleMembers do
  use Ecto.Migration

  def change do
    alter table(:ensemble_members) do
      add :headshot_path, :string, null: false, default: ""
    end
  end
end
