defmodule EstherPictures.Content.Clip do
  @moduledoc "A clip shown in the hero filmstrip."
  use Ecto.Schema
  import Ecto.Changeset

  schema "clips" do
    field :position, :integer, default: 0
    field :title, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(clip, attrs) do
    clip
    |> cast(attrs, [:position, :title])
    |> validate_required([:title])
    |> validate_length(:title, max: 120)
  end
end
