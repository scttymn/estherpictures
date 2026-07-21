defmodule EstherPicturesWeb.Admin.EnsembleMemberController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.{Content, Uploads}
  alias EstherPictures.Content.EnsembleMember

  def index(conn, _params) do
    render(conn, :index, members: Content.list_ensemble_members())
  end

  def new(conn, _params) do
    render(conn, :new, changeset: Content.change_ensemble_member(%EnsembleMember{}))
  end

  def create(conn, %{"ensemble_member" => params}) do
    case handle_headshot(params) do
      {:ok, params} ->
        case Content.create_ensemble_member(params) do
          {:ok, _} ->
            conn |> put_flash(:info, "Member added.") |> redirect(to: ~p"/admin/ensemble")

          {:error, changeset} ->
            render(conn, :new, changeset: changeset)
        end

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> render(:new,
          changeset: Content.change_ensemble_member(%EnsembleMember{}, drop_upload(params))
        )
    end
  end

  def edit(conn, %{"id" => id}) do
    member = Content.get_ensemble_member!(id)
    render(conn, :edit, member: member, changeset: Content.change_ensemble_member(member))
  end

  def update(conn, %{"id" => id, "ensemble_member" => params}) do
    member = Content.get_ensemble_member!(id)

    case handle_headshot(params) do
      {:ok, params} ->
        case Content.update_ensemble_member(member, params, conn.assigns.current_scope.user) do
          {:ok, _} ->
            conn |> put_flash(:info, "Member updated.") |> redirect(to: ~p"/admin/ensemble")

          {:error, changeset} ->
            render(conn, :edit, member: member, changeset: changeset)
        end

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> render(:edit,
          member: member,
          changeset: Content.change_ensemble_member(member, drop_upload(params))
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    member = Content.get_ensemble_member!(id)
    {:ok, _} = Content.delete_ensemble_member(member, conn.assigns.current_scope.user)
    conn |> put_flash(:info, "Member removed.") |> redirect(to: ~p"/admin/ensemble")
  end

  # Stores an uploaded headshot (if one was provided) and folds the path into
  # the params. Replaced files stay on disk while version snapshots still
  # reference them; Content GC removes them once nothing points at them.
  defp handle_headshot(params) do
    case params["headshot"] do
      %Plug.Upload{} = upload ->
        case Uploads.store_image(upload, "cast") do
          {:ok, path} ->
            {:ok, params |> drop_upload() |> Map.put("headshot_path", path)}

          {:error, _} = err ->
            err
        end

      _ ->
        {:ok, drop_upload(params)}
    end
  end

  defp drop_upload(params), do: Map.delete(params, "headshot")
end
