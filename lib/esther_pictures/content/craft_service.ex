defmodule EstherPictures.Content.CraftService do
  @moduledoc "A single 'what we do' service in the craft grid."
  use Ecto.Schema
  import Ecto.Changeset

  schema "craft_services" do
    field :position, :integer, default: 0
    field :title, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(service, attrs) do
    service
    |> cast(attrs, [:position, :title, :description])
    |> validate_required([:title])
    |> validate_length(:title, max: 120)
  end
end
