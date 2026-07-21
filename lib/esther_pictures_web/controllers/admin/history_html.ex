defmodule EstherPicturesWeb.Admin.HistoryHTML do
  use EstherPicturesWeb, :html

  embed_templates "history_html/*"

  @doc "Human name for a versioned item type, e.g. \"Craft service\"."
  def type_name("ensemble_member"), do: "Cast member"

  def type_name(item_type) do
    item_type |> String.replace("_", " ") |> String.capitalize()
  end

  @doc "Best display label for a snapshot: its title/name, if it has one."
  def item_label(%{data: data}) do
    data["title"] || data["name"] || data["collective_name"]
  end

  @doc "Human name for a snapshot field, e.g. \"video url\"."
  def field_name(field), do: String.replace(field, "_", " ")

  @doc "A field value ready for the before/after diff columns."
  def field_value(nil), do: "—"
  def field_value(""), do: "—"
  def field_value(value), do: to_string(value)
end
