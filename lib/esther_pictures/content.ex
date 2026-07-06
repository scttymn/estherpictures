defmodule EstherPictures.Content do
  @moduledoc """
  The Content context — all editable copy and collections shown on the public
  site. Everything here is managed from the admin so non-developers can update
  the site without touching code.

  Updates and deletes record a `ContentVersion` snapshot of the record's prior
  state (see `list_versions/1` and `restore_version/2`) so admins can roll
  back bad edits. Old versions are pruned per item; clip thumbnails on disk
  are kept as long as any live clip or retained snapshot references them.
  """

  import Ecto.Query, warn: false
  alias EstherPictures.{Repo, Uploads}

  alias EstherPictures.Content.{
    SiteSetting,
    CraftService,
    Clip,
    EnsembleMember,
    ContentVersion
  }

  @item_types %{
    "site_setting" => SiteSetting,
    "craft_service" => CraftService,
    "clip" => Clip,
    "ensemble_member" => EnsembleMember
  }

  # How many snapshots to retain per item before old ones are pruned.
  @keep_versions 20

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

  def update_site_settings(%SiteSetting{} = setting, attrs, actor \\ nil) do
    setting
    |> SiteSetting.changeset(attrs)
    |> Repo.update()
    |> record_version("update", setting, actor)
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

  def update_craft_service(%CraftService{} = s, attrs, actor \\ nil) do
    s |> CraftService.changeset(attrs) |> Repo.update() |> record_version("update", s, actor)
  end

  def delete_craft_service(%CraftService{} = s, actor \\ nil),
    do: s |> Repo.delete() |> record_version("delete", s, actor)

  ## Clips --------------------------------------------------------------------

  def list_clips do
    from(c in Clip, order_by: [asc: c.position, asc: c.id]) |> Repo.all()
  end

  def get_clip!(id), do: Repo.get!(Clip, id)

  def change_clip(%Clip{} = c, attrs \\ %{}), do: Clip.changeset(c, attrs)

  def create_clip(attrs), do: %Clip{} |> Clip.changeset(attrs) |> Repo.insert()

  def update_clip(%Clip{} = c, attrs, actor \\ nil) do
    c |> Clip.changeset(attrs) |> Repo.update() |> record_version("update", c, actor)
  end

  def delete_clip(%Clip{} = c, actor \\ nil),
    do: c |> Repo.delete() |> record_version("delete", c, actor)

  ## Ensemble members ---------------------------------------------------------

  def list_ensemble_members do
    from(m in EnsembleMember, order_by: [asc: m.position, asc: m.id]) |> Repo.all()
  end

  def get_ensemble_member!(id), do: Repo.get!(EnsembleMember, id)

  def change_ensemble_member(%EnsembleMember{} = m, attrs \\ %{}),
    do: EnsembleMember.changeset(m, attrs)

  def create_ensemble_member(attrs),
    do: %EnsembleMember{} |> EnsembleMember.changeset(attrs) |> Repo.insert()

  def update_ensemble_member(%EnsembleMember{} = m, attrs, actor \\ nil) do
    m |> EnsembleMember.changeset(attrs) |> Repo.update() |> record_version("update", m, actor)
  end

  def delete_ensemble_member(%EnsembleMember{} = m, actor \\ nil),
    do: m |> Repo.delete() |> record_version("delete", m, actor)

  ## Version history ----------------------------------------------------------

  def list_versions(limit \\ 100) do
    from(v in ContentVersion,
      order_by: [desc: v.inserted_at, desc: v.id],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  def get_version!(id), do: Repo.get!(ContentVersion, id) |> Repo.preload(:user)

  @doc """
  Versions paired with a field-level diff of what that change did: a list of
  `{field, before, after}` tuples. A version stores the state BEFORE its
  change, so "after" comes from the next-newer version of the same item — or
  from the record itself for the item's most recent version. Deletions list
  every field with a nil "after".
  """
  def list_versions_with_changes(limit \\ 100) do
    versions = list_versions(limit)

    after_data_by_version_id =
      versions
      |> Enum.group_by(&{&1.item_type, &1.item_id})
      |> Enum.flat_map(fn {{item_type, item_id}, group} ->
        # group is newest-first (list_versions order is preserved).
        afters = [current_data(item_type, item_id) | Enum.map(group, & &1.data)]
        Enum.zip(Enum.map(group, & &1.id), afters)
      end)
      |> Map.new()

    Enum.map(versions, fn v -> {v, changes(v, after_data_by_version_id[v.id])} end)
  end

  defp current_data(item_type, item_id) do
    case Repo.get(item_schema(item_type), item_id) do
      nil -> nil
      record -> snapshot(record)
    end
  end

  defp changes(%ContentVersion{action: "delete", data: before}, _after_data),
    do: Enum.sort(for {field, value} <- before, not is_nil(norm(value)), do: {field, value, nil})

  defp changes(%ContentVersion{data: before}, after_data) when is_map(after_data) do
    for field <- Enum.sort(Enum.uniq(Map.keys(before) ++ Map.keys(after_data))),
        norm(Map.get(before, field)) != norm(Map.get(after_data, field)),
        do: {field, Map.get(before, field), Map.get(after_data, field)}
  end

  # The record is gone (deleted, or removed outside the context by e.g.
  # reseeding) — every non-empty field it had was lost.
  defp changes(%ContentVersion{data: before}, nil),
    do: Enum.sort(for {field, value} <- before, not is_nil(norm(value)), do: {field, value, nil})

  # Blank and unset are the same thing to an editor (and several columns are
  # NOT NULL with a "" default the in-memory struct may not carry).
  defp norm(""), do: nil
  defp norm(value), do: value

  @doc """
  Writes a snapshot back. For an "update" version the current record is
  updated to the snapshotted state; for a "delete" version (or if the record
  was deleted since) it is re-inserted under its original id. The restore
  itself is recorded as a new version, so it can be undone too.
  """
  def restore_version(%ContentVersion{} = version, actor \\ nil) do
    schema = Map.fetch!(@item_types, version.item_type)

    case Repo.get(schema, version.item_id) do
      nil ->
        struct(schema, id: version.item_id)
        |> restore_changeset(schema, version.data)
        |> Repo.insert()

      current ->
        current
        |> restore_changeset(schema, version.data)
        |> Repo.update()
        |> record_version("update", current, actor)
    end
  end

  # A direct change rather than the schema's cast/validate changeset: the
  # snapshot was valid when recorded, and cast would silently skip empty
  # strings — leaving a field that was blank before the bad edit unrestored.
  defp restore_changeset(record, schema, data) do
    attrs =
      schema.__schema__(:fields)
      |> Kernel.--([:id, :inserted_at, :updated_at])
      |> Enum.filter(&Map.has_key?(data, Atom.to_string(&1)))
      |> Map.new(fn field -> {field, Map.get(data, Atom.to_string(field))} end)

    Ecto.Changeset.change(record, attrs)
  end

  @doc "The module versioned under the given `item_type` string."
  def item_schema(item_type), do: Map.fetch!(@item_types, item_type)

  @doc """
  Discards a single version snapshot, then sweeps any image files nothing
  references anymore.
  """
  def delete_version(%ContentVersion{} = version) do
    {:ok, deleted} = Repo.delete(version)
    sweep_orphaned_thumbnails()
    {:ok, deleted}
  end

  @doc """
  Discards all version history and sweeps the uploads directory: any thumbnail
  no live clip or remaining snapshot references is deleted from disk. Returns
  `{versions_cleared, files_deleted}`.
  """
  def clear_versions do
    {cleared, _} = Repo.delete_all(ContentVersion)
    {cleared, sweep_orphaned_thumbnails()}
  end

  defp sweep_orphaned_thumbnails do
    snapshot_paths =
      from(v in ContentVersion, where: v.item_type == "clip", select: v.data)
      |> Repo.all()
      |> Enum.map(& &1["thumbnail_path"])

    live_paths = from(c in Clip, select: c.thumbnail_path) |> Repo.all()
    referenced = MapSet.new(live_paths ++ snapshot_paths)

    Uploads.list("clips")
    |> Enum.reject(&MapSet.member?(referenced, &1))
    |> Enum.map(&Uploads.delete/1)
    |> length()
  end

  defp record_version({:ok, _} = result, action, %schema{} = old, actor) do
    item_type = item_type_for(schema)

    Repo.insert!(%ContentVersion{
      item_type: item_type,
      item_id: old.id,
      action: action,
      data: snapshot(old),
      user_id: actor && actor.id
    })

    prune_versions(item_type, old.id)
    result
  end

  defp record_version(result, _action, _old, _actor), do: result

  defp item_type_for(schema) do
    {item_type, _} = Enum.find(@item_types, fn {_, mod} -> mod == schema end)
    item_type
  end

  # The record's editable fields, JSON-safe, ready to feed back into its
  # changeset on restore. Nil fields are omitted: several columns are NOT NULL
  # with a DB default the in-memory struct may not carry, and casting an
  # explicit nil back would violate the constraint.
  defp snapshot(%schema{} = record) do
    schema.__schema__(:fields)
    |> Kernel.--([:id, :inserted_at, :updated_at])
    |> Enum.reject(&is_nil(Map.get(record, &1)))
    |> Map.new(fn field -> {Atom.to_string(field), Map.get(record, field)} end)
  end

  # Keep the newest @keep_versions snapshots for an item; delete the rest,
  # then remove any thumbnail files nothing references anymore.
  defp prune_versions(item_type, item_id) do
    keep_ids =
      from(v in ContentVersion,
        where: v.item_type == ^item_type and v.item_id == ^item_id,
        order_by: [desc: v.inserted_at, desc: v.id],
        limit: @keep_versions,
        select: v.id
      )
      |> Repo.all()

    {pruned, _} =
      from(v in ContentVersion,
        where: v.item_type == ^item_type and v.item_id == ^item_id and v.id not in ^keep_ids
      )
      |> Repo.delete_all()

    if pruned > 0, do: sweep_orphaned_thumbnails()
  end

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
