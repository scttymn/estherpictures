defmodule EstherPictures.ContentVersioningTest do
  # Not async: SQLite allows a single writer, and these tests write heavily.
  use EstherPictures.DataCase, async: false

  import EstherPictures.AccountsFixtures

  alias EstherPictures.{Content, Uploads}
  alias EstherPictures.Content.ContentVersion
  alias EstherPictures.Repo

  defp clip_fixture(attrs \\ %{}) do
    {:ok, clip} =
      attrs
      |> Enum.into(%{"title" => "Night Swim", "runtime" => "12 MIN"})
      |> Content.create_clip()

    # Reload so DB defaults ("" on NOT NULL columns) are present, the same
    # shape controllers work with.
    Content.get_clip!(clip.id)
  end

  defp versions_for(clip) do
    Repo.all(
      from v in ContentVersion,
        where: v.item_type == "clip" and v.item_id == ^clip.id,
        order_by: [asc: v.id]
    )
  end

  describe "version recording" do
    test "update records a snapshot of the prior state with the actor" do
      user = user_fixture()
      clip = clip_fixture()

      {:ok, _} = Content.update_clip(clip, %{"title" => "Day Swim"}, user)

      assert [%ContentVersion{action: "update", data: data, user_id: user_id}] =
               versions_for(clip)

      assert data["title"] == "Night Swim"
      assert data["runtime"] == "12 MIN"
      assert user_id == user.id
    end

    test "delete records a snapshot" do
      clip = clip_fixture()
      {:ok, _} = Content.delete_clip(clip)

      assert [%ContentVersion{action: "delete", data: %{"title" => "Night Swim"}}] =
               versions_for(clip)
    end

    test "failed update records nothing" do
      clip = clip_fixture()
      {:error, _} = Content.update_clip(clip, %{"title" => nil})
      assert versions_for(clip) == []
    end
  end

  describe "restore_version/2" do
    test "reverts an update and records the pre-restore state" do
      clip = clip_fixture()
      {:ok, _} = Content.update_clip(clip, %{"title" => "Ruined by editor"})

      [version] = versions_for(clip)
      {:ok, restored} = Content.restore_version(version)

      assert restored.title == "Night Swim"
      # The restore snapshotted the bad state, so it can be undone too.
      assert [_, %ContentVersion{data: %{"title" => "Ruined by editor"}}] = versions_for(clip)
    end

    test "revert re-clears a field the bad edit filled in" do
      clip = clip_fixture()
      assert clip.format == ""

      {:ok, _} = Content.update_clip(clip, %{"format" => "JUNK"})

      [version] = versions_for(clip)
      {:ok, restored} = Content.restore_version(version)
      assert restored.format == ""
    end

    test "re-inserts a deleted record under its original id" do
      clip = clip_fixture()
      {:ok, _} = Content.delete_clip(clip)

      [version] = versions_for(clip)
      {:ok, restored} = Content.restore_version(version)

      assert restored.id == clip.id
      assert restored.title == "Night Swim"
      assert Content.get_clip!(clip.id).title == "Night Swim"
    end
  end

  describe "list_versions_with_changes/1" do
    test "diffs each version against the next-newer state" do
      clip = clip_fixture()
      {:ok, clip} = Content.update_clip(clip, %{"title" => "Middle", "runtime" => "20 MIN"})
      {:ok, _} = Content.update_clip(clip, %{"title" => "Final"})

      # Newest first: the second edit, then the first.
      assert [{_, second_changes}, {_, first_changes}] = Content.list_versions_with_changes()
      assert second_changes == [{"title", "Middle", "Final"}]
      assert first_changes == [{"runtime", "12 MIN", "20 MIN"}, {"title", "Night Swim", "Middle"}]
    end

    test "a deletion lists every field with no after value" do
      clip = clip_fixture()
      {:ok, _} = Content.delete_clip(clip)

      assert [{%ContentVersion{action: "delete"}, changes}] = Content.list_versions_with_changes()
      assert {"title", "Night Swim", nil} in changes
    end

    test "a no-op save shows an empty diff" do
      clip = clip_fixture()
      {:ok, _} = Content.update_clip(clip, %{"title" => "Night Swim"})

      assert [{_, []}] = Content.list_versions_with_changes()
    end
  end

  describe "pruning and thumbnail GC" do
    setup do
      root = Application.get_env(:esther_pictures, Uploads)[:root]
      dir = Path.join(root, "clips")
      File.rm_rf!(dir)
      File.mkdir_p!(dir)
      %{dir: dir}
    end

    defp touch_thumbnail(dir, name) do
      File.write!(Path.join(dir, name), "img")
      "/uploads/clips/#{name}"
    end

    test "keeps only the newest 20 versions per item", %{dir: dir} do
      clip = clip_fixture(%{"thumbnail_path" => touch_thumbnail(dir, "keep.jpg")})

      clip =
        Enum.reduce(1..25, clip, fn i, c ->
          {:ok, c} = Content.update_clip(c, %{"title" => "Title #{i}"})
          c
        end)

      assert length(versions_for(clip)) == 20
    end

    test "delete_version discards one snapshot and sweeps files only it referenced",
         %{dir: dir} do
      old_path = touch_thumbnail(dir, "old.jpg")
      new_path = touch_thumbnail(dir, "new.jpg")

      clip = clip_fixture(%{"thumbnail_path" => old_path})
      {:ok, _} = Content.update_clip(clip, %{"thumbnail_path" => new_path})

      [version] = Content.list_versions()
      {:ok, _} = Content.delete_version(version)

      assert Content.list_versions() == []
      refute File.exists?(Path.join(dir, "old.jpg"))
      assert File.exists?(Path.join(dir, "new.jpg"))
    end

    test "clear_versions discards all history and sweeps unreferenced files", %{dir: dir} do
      live_path = touch_thumbnail(dir, "live.jpg")
      touch_thumbnail(dir, "orphan.jpg")

      clip = clip_fixture(%{"thumbnail_path" => live_path})
      {:ok, _} = Content.update_clip(clip, %{"title" => "Edited"})

      assert {1, 1} = Content.clear_versions()

      assert Content.list_versions() == []
      assert File.exists?(Path.join(dir, "live.jpg"))
      refute File.exists?(Path.join(dir, "orphan.jpg"))
    end

    test "deletes a thumbnail once nothing references it, keeps it while a snapshot does",
         %{dir: dir} do
      old_path = touch_thumbnail(dir, "old.jpg")
      new_path = touch_thumbnail(dir, "new.jpg")
      old_file = Path.join(dir, "old.jpg")

      clip = clip_fixture(%{"thumbnail_path" => old_path})
      {:ok, clip} = Content.update_clip(clip, %{"thumbnail_path" => new_path})

      # The old thumbnail is only referenced by version snapshots now, but must
      # survive as long as one of them is retained.
      assert File.exists?(old_file)

      # Push enough edits that every snapshot referencing old.jpg gets pruned.
      Enum.reduce(1..21, clip, fn i, c ->
        {:ok, c} = Content.update_clip(c, %{"title" => "Title #{i}"})
        c
      end)

      refute File.exists?(old_file)
      assert File.exists?(Path.join(dir, "new.jpg"))
    end
  end
end
