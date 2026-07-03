defmodule EstherPicturesWeb.Admin.ClipController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Content
  alias EstherPictures.Content.Clip

  def index(conn, _params) do
    render(conn, :index, clips: Content.list_clips())
  end

  def new(conn, _params) do
    render(conn, :new, changeset: Content.change_clip(%Clip{}))
  end

  def create(conn, %{"clip" => params}) do
    case Content.create_clip(params) do
      {:ok, _} -> conn |> put_flash(:info, "Clip added.") |> redirect(to: ~p"/admin/clips")
      {:error, changeset} -> render(conn, :new, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    clip = Content.get_clip!(id)
    render(conn, :edit, clip: clip, changeset: Content.change_clip(clip))
  end

  def update(conn, %{"id" => id, "clip" => params}) do
    clip = Content.get_clip!(id)

    case Content.update_clip(clip, params) do
      {:ok, _} -> conn |> put_flash(:info, "Clip updated.") |> redirect(to: ~p"/admin/clips")
      {:error, changeset} -> render(conn, :edit, clip: clip, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    clip = Content.get_clip!(id)
    {:ok, _} = Content.delete_clip(clip)
    conn |> put_flash(:info, "Clip removed.") |> redirect(to: ~p"/admin/clips")
  end
end
