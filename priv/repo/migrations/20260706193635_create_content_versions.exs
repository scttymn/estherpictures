defmodule EstherPictures.Repo.Migrations.CreateContentVersions do
  use Ecto.Migration

  def change do
    create table(:content_versions) do
      add :item_type, :string, null: false
      add :item_id, :integer, null: false
      add :action, :string, null: false
      add :data, :map, null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:content_versions, [:item_type, :item_id])
    create index(:content_versions, [:inserted_at])
  end
end
