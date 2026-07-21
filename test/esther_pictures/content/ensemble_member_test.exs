defmodule EstherPictures.Content.EnsembleMemberTest do
  # Not async: SQLite allows a single writer; keep write tests sequential.
  use EstherPictures.DataCase, async: false

  alias EstherPictures.Content
  alias EstherPictures.Content.EnsembleMember

  describe "changeset/2" do
    test "accepts bio along with name, role, and since_year" do
      changeset =
        EnsembleMember.changeset(%EnsembleMember{}, %{
          "name" => "Michael Joiner",
          "role" => "FOUNDER / ACTOR / WRITER / DIRECTOR",
          "since_year" => "1991",
          "bio" => "A lifelong student of the craft."
        })

      assert changeset.valid?
      assert get_change(changeset, :bio) == "A lifelong student of the craft."
    end

    test "allows blank bio" do
      changeset =
        EnsembleMember.changeset(%EnsembleMember{}, %{
          "name" => "Mara Vance",
          "role" => "FOUNDER / WRITER-DIRECTOR",
          "bio" => ""
        })

      assert changeset.valid?
    end

    test "requires name" do
      changeset = EnsembleMember.changeset(%EnsembleMember{}, %{"bio" => "No name"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "create_ensemble_member/1" do
    test "persists bio and headshot_path" do
      assert {:ok, member} =
               Content.create_ensemble_member(%{
                 "name" => "Michael Joiner",
                 "role" => "FOUNDER / ACTOR",
                 "since_year" => "1991",
                 "bio" => "Creates memorable stories.",
                 "headshot_path" => "/uploads/cast/mj.jpg"
               })

      assert member.bio == "Creates memorable stories."
      assert member.headshot_path == "/uploads/cast/mj.jpg"
      reloaded = Content.get_ensemble_member!(member.id)
      assert reloaded.bio == "Creates memorable stories."
      assert reloaded.headshot_path == "/uploads/cast/mj.jpg"
    end
  end

  describe "bio_present?/1" do
    test "is true for non-blank bio" do
      assert EnsembleMember.bio_present?("A lifelong student.")
      assert EnsembleMember.bio_present?(%EnsembleMember{bio: "Hello"})
    end

    test "is false for blank bio" do
      refute EnsembleMember.bio_present?("")
      refute EnsembleMember.bio_present?("   ")
      refute EnsembleMember.bio_present?(nil)
      refute EnsembleMember.bio_present?(%EnsembleMember{bio: ""})
    end
  end
end
