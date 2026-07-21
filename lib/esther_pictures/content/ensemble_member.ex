defmodule EstherPictures.Content.EnsembleMember do
  @moduledoc "A person in the ensemble roster."
  use Ecto.Schema
  import Ecto.Changeset

  schema "ensemble_members" do
    field :position, :integer, default: 0
    field :name, :string
    field :role, :string
    field :since_year, :string
    field :bio, :string, default: ""

    timestamps(type: :utc_datetime)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:position, :name, :role, :since_year, :bio])
    |> validate_required([:name])
    |> validate_length(:name, max: 120)
  end

  @doc "True when a cast bio should render as an expandable accordion."
  def bio_present?(%__MODULE__{bio: bio}), do: bio_present?(bio)
  def bio_present?(bio) when is_binary(bio), do: String.trim(bio) != ""
  def bio_present?(_), do: false
end
