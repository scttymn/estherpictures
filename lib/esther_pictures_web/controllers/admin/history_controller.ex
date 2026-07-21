defmodule EstherPicturesWeb.Admin.HistoryController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Content
  alias EstherPicturesWeb.Admin.HistoryHTML

  def index(conn, _params) do
    render(conn, :index, entries: Content.list_versions_with_changes())
  end

  def clear(conn, _params) do
    {cleared, files_deleted} = Content.clear_versions()

    conn
    |> put_flash(
      :info,
      "Discarded #{cleared} history #{if cleared == 1, do: "entry", else: "entries"} " <>
        "and deleted #{files_deleted} unused #{if files_deleted == 1, do: "image", else: "images"}."
    )
    |> redirect(to: ~p"/admin/history")
  end

  def delete(conn, %{"id" => id}) do
    {:ok, _} = id |> Content.get_version!() |> Content.delete_version()

    conn
    |> put_flash(:info, "History entry discarded.")
    |> redirect(to: ~p"/admin/history")
  end

  def restore(conn, %{"id" => id}) do
    version = Content.get_version!(id)

    case Content.restore_version(version, conn.assigns.current_scope.user) do
      {:ok, _} ->
        conn
        |> put_flash(
          :info,
          "Restored #{HistoryHTML.type_name(version.item_type) |> String.downcase()}."
        )
        |> redirect(to: ~p"/admin/history")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not restore that version.")
        |> redirect(to: ~p"/admin/history")
    end
  end
end
