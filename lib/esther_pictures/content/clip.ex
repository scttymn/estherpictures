defmodule EstherPictures.Content.Clip do
  @moduledoc """
  A clip/reel: a YouTube or Vimeo video with its own slate stats and an
  uploaded thumbnail image. The first clip auto-plays in the hero; clicking a
  clip in the filmstrip makes it the active, looping clip.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "clips" do
    field :position, :integer, default: 0
    field :title, :string
    field :video_url, :string
    field :thumbnail_path, :string

    # Slate stats shown on the left while this clip is active.
    field :runtime, :string
    field :format, :string
    field :years, :string
    field :status, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(clip, attrs) do
    clip
    |> cast(attrs, [:position, :title, :video_url, :thumbnail_path, :runtime, :format, :years, :status])
    |> validate_required([:title])
    |> validate_length(:title, max: 120)
  end
end
