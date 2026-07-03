defmodule EstherPictures.Repo.Migrations.AddReelVideoToSiteSettings do
  use Ecto.Migration

  def change do
    alter table(:site_settings) do
      add :reel_video_url, :string, null: false, default: ""
      add :reel_poster_url, :string, null: false, default: ""
    end
  end
end
