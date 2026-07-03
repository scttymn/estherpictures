defmodule EstherPictures.Repo.Migrations.ClipsBecomeReels do
  use Ecto.Migration

  def change do
    # Each clip is now a full reel: its own video, slate stats, and an
    # uploaded thumbnail image.
    alter table(:clips) do
      add :video_url, :string, null: false, default: ""
      add :thumbnail_path, :string, null: false, default: ""
      add :runtime, :string, null: false, default: ""
      add :format, :string, null: false, default: ""
      add :years, :string, null: false, default: ""
      add :status, :string, null: false, default: ""
    end

    # The standalone hero reel is retired — clips drive the hero now.
    alter table(:site_settings) do
      remove :reel_video_url, :string, null: false, default: ""
      remove :reel_poster_url, :string, null: false, default: ""
      remove :reel_title, :string, null: false, default: ""
      remove :reel_runtime, :string, null: false, default: ""
      remove :reel_format, :string, null: false, default: ""
      remove :reel_years, :string, null: false, default: ""
      remove :reel_status, :string, null: false, default: ""
    end
  end
end
