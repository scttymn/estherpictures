defmodule EstherPicturesWeb.Admin.ClipController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.{Content, Uploads}
  alias EstherPictures.Content.Clip

  def index(conn, _params) do
    render(conn, :index, clips: Content.list_clips())
  end

  def new(conn, _params) do
    render(conn, :new, changeset: Content.change_clip(%Clip{}))
  end

  def create(conn, %{"clip" => params}) do
    case handle_thumbnail(params, nil) do
      {:ok, params} ->
        case Content.create_clip(params) do
          {:ok, _} -> conn |> put_flash(:info, "Clip added.") |> redirect(to: ~p"/admin/clips")
          {:error, changeset} -> render(conn, :new, changeset: changeset)
        end

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> render(:new, changeset: Content.change_clip(%Clip{}, drop_upload(params)))
    end
  end

  def edit(conn, %{"id" => id}) do
    clip = Content.get_clip!(id)
    render(conn, :edit, clip: clip, changeset: Content.change_clip(clip))
  end

  def update(conn, %{"id" => id, "clip" => params}) do
    clip = Content.get_clip!(id)

    case handle_thumbnail(params, clip) do
      {:ok, params} ->
        case Content.update_clip(clip, params) do
          {:ok, _} -> conn |> put_flash(:info, "Clip updated.") |> redirect(to: ~p"/admin/clips")
          {:error, changeset} -> render(conn, :edit, clip: clip, changeset: changeset)
        end

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> render(:edit, clip: clip, changeset: Content.change_clip(clip, drop_upload(params)))
    end
  end

  def delete(conn, %{"id" => id}) do
    clip = Content.get_clip!(id)
    {:ok, _} = Content.delete_clip(clip)
    Uploads.delete(clip.thumbnail_path)
    conn |> put_flash(:info, "Clip removed.") |> redirect(to: ~p"/admin/clips")
  end

  # Stores an uploaded thumbnail (if one was provided) and folds the resulting
  # path into the params, deleting any previous thumbnail. If no file was
  # provided, leaves the existing thumbnail untouched.
  defp handle_thumbnail(params, clip) do
    case params["thumbnail"] do
      %Plug.Upload{} = upload ->
        case Uploads.store_image(upload, "clips") do
          {:ok, path} ->
            if clip, do: Uploads.delete(clip.thumbnail_path)
            {:ok, params |> drop_upload() |> Map.put("thumbnail_path", path)}

          {:error, _} = err ->
            err
        end

      _ ->
        {:ok, drop_upload(params)}
    end
  end

  defp drop_upload(params), do: Map.delete(params, "thumbnail")
end
