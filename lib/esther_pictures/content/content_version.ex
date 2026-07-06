defmodule EstherPictures.Content.ContentVersion do
  @moduledoc """
  A snapshot of a content record taken just before it was updated or deleted,
  so an admin can roll back bad edits. `data` holds the record's editable
  fields as they were BEFORE the change; restoring writes them back through
  the normal changeset.
  """
  use Ecto.Schema

  schema "content_versions" do
    field :item_type, :string
    field :item_id, :integer
    field :action, :string
    field :data, :map

    belongs_to :user, EstherPictures.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
