defmodule EstherPictures.Repo.Migrations.CreateContentTables do
  use Ecto.Migration

  def change do
    # Singleton row holding all one-off site copy. Enforced to a single row
    # (id = 1) by the Content context.
    create table(:site_settings) do
      add :collective_name, :string, null: false, default: "ESTHER PICTURES"
      add :tagline, :string, null: false, default: ""
      add :hero_heading, :string, null: false, default: ""

      # Reel slate metadata
      add :reel_title, :string, null: false, default: "Highlight Reel"
      add :reel_runtime, :string, null: false, default: ""
      add :reel_format, :string, null: false, default: ""
      add :reel_years, :string, null: false, default: ""
      add :reel_status, :string, null: false, default: ""

      # Contact / footer
      add :contact_heading, :string, null: false, default: ""
      add :email, :string, null: false, default: ""
      add :studio_locations, :string, null: false, default: ""
      add :instagram_url, :string, null: false, default: ""
      add :letterboxd_url, :string, null: false, default: ""
      add :footer_text, :string, null: false, default: ""

      timestamps(type: :utc_datetime)
    end

    create table(:craft_services) do
      add :position, :integer, null: false, default: 0
      add :title, :string, null: false
      add :description, :text, null: false, default: ""

      timestamps(type: :utc_datetime)
    end

    create index(:craft_services, [:position])

    create table(:clips) do
      add :position, :integer, null: false, default: 0
      add :title, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:clips, [:position])

    create table(:ensemble_members) do
      add :position, :integer, null: false, default: 0
      add :name, :string, null: false
      add :role, :string, null: false, default: ""
      add :since_year, :string, null: false, default: ""

      timestamps(type: :utc_datetime)
    end

    create index(:ensemble_members, [:position])
  end
end
