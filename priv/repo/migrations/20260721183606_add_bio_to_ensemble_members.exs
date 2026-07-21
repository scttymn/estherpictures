defmodule EstherPictures.Repo.Migrations.AddBioToEnsembleMembers do
  use Ecto.Migration

  def change do
    alter table(:ensemble_members) do
      add :bio, :string, null: false, default: ""
    end
  end
end
