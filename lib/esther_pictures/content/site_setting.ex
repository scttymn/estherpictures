defmodule EstherPictures.Content.SiteSetting do
  @moduledoc """
  A singleton row holding all one-off site copy edited from the admin.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "site_settings" do
    field :collective_name, :string
    field :tagline, :string
    field :hero_heading, :string

    field :contact_heading, :string
    field :email, :string
    field :studio_locations, :string
    field :instagram_url, :string
    field :letterboxd_url, :string
    field :footer_text, :string

    timestamps(type: :utc_datetime)
  end

  @fields ~w(collective_name tagline hero_heading contact_heading email
             studio_locations instagram_url letterboxd_url footer_text)a

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, @fields)
    |> validate_required([:collective_name])
    |> validate_length(:collective_name, max: 120)
  end
end
