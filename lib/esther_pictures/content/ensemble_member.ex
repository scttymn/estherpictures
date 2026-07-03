defmodule EstherPictures.Content.EnsembleMember do
  @moduledoc "A person in the ensemble roster."
  use Ecto.Schema
  import Ecto.Changeset

  schema "ensemble_members" do
    field :position, :integer, default: 0
    field :name, :string
    field :role, :string
    field :since_year, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:position, :name, :role, :since_year])
    |> validate_required([:name])
    |> validate_length(:name, max: 120)
  end
end
