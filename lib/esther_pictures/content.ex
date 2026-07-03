defmodule EstherPictures.Content do
  @moduledoc """
  The Content context — all editable copy and collections shown on the public
  site. Everything here is managed from the admin so non-developers can update
  the site without touching code.
  """

  import Ecto.Query, warn: false
  alias EstherPictures.Repo

  alias EstherPictures.Content.{SiteSetting, CraftService, Clip, EnsembleMember}

  ## Site settings (singleton) ------------------------------------------------

  @doc """
  Returns the site settings row, creating it with defaults if it does not exist.
  """
  def get_site_settings do
    case Repo.get(SiteSetting, 1) do
      nil ->
        {:ok, setting} =
          %SiteSetting{id: 1}
          |> SiteSetting.changeset(%{collective_name: "ESTHER PICTURES"})
          |> Repo.insert()

        setting

      setting ->
        setting
    end
  end

  def change_site_settings(%SiteSetting{} = setting, attrs \\ %{}) do
    SiteSetting.changeset(setting, attrs)
  end

  def update_site_settings(%SiteSetting{} = setting, attrs) do
    setting
    |> SiteSetting.changeset(attrs)
    |> Repo.update()
  end

  ## Craft services -----------------------------------------------------------

  def list_craft_services do
    from(c in CraftService, order_by: [asc: c.position, asc: c.id]) |> Repo.all()
  end

  def get_craft_service!(id), do: Repo.get!(CraftService, id)

  def change_craft_service(%CraftService{} = s, attrs \\ %{}),
    do: CraftService.changeset(s, attrs)

  def create_craft_service(attrs),
    do: %CraftService{} |> CraftService.changeset(attrs) |> Repo.insert()

  def update_craft_service(%CraftService{} = s, attrs),
    do: s |> CraftService.changeset(attrs) |> Repo.update()

  def delete_craft_service(%CraftService{} = s), do: Repo.delete(s)

  ## Clips --------------------------------------------------------------------

  def list_clips do
    from(c in Clip, order_by: [asc: c.position, asc: c.id]) |> Repo.all()
  end

  def get_clip!(id), do: Repo.get!(Clip, id)

  def change_clip(%Clip{} = c, attrs \\ %{}), do: Clip.changeset(c, attrs)

  def create_clip(attrs), do: %Clip{} |> Clip.changeset(attrs) |> Repo.insert()

  def update_clip(%Clip{} = c, attrs), do: c |> Clip.changeset(attrs) |> Repo.update()

  def delete_clip(%Clip{} = c), do: Repo.delete(c)

  ## Ensemble members ---------------------------------------------------------

  def list_ensemble_members do
    from(m in EnsembleMember, order_by: [asc: m.position, asc: m.id]) |> Repo.all()
  end

  def get_ensemble_member!(id), do: Repo.get!(EnsembleMember, id)

  def change_ensemble_member(%EnsembleMember{} = m, attrs \\ %{}),
    do: EnsembleMember.changeset(m, attrs)

  def create_ensemble_member(attrs),
    do: %EnsembleMember{} |> EnsembleMember.changeset(attrs) |> Repo.insert()

  def update_ensemble_member(%EnsembleMember{} = m, attrs),
    do: m |> EnsembleMember.changeset(attrs) |> Repo.update()

  def delete_ensemble_member(%EnsembleMember{} = m), do: Repo.delete(m)

  ## Aggregate for the public page --------------------------------------------

  @doc """
  Bundles everything the public home page needs in one call.
  """
  def home_page_data do
    %{
      settings: get_site_settings(),
      craft: list_craft_services(),
      clips: list_clips(),
      ensemble: list_ensemble_members()
    }
  end
end
