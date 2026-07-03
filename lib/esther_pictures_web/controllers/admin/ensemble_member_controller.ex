defmodule EstherPicturesWeb.Admin.EnsembleMemberController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Content
  alias EstherPictures.Content.EnsembleMember

  def index(conn, _params) do
    render(conn, :index, members: Content.list_ensemble_members())
  end

  def new(conn, _params) do
    render(conn, :new, changeset: Content.change_ensemble_member(%EnsembleMember{}))
  end

  def create(conn, %{"ensemble_member" => params}) do
    case Content.create_ensemble_member(params) do
      {:ok, _} -> conn |> put_flash(:info, "Member added.") |> redirect(to: ~p"/admin/ensemble")
      {:error, changeset} -> render(conn, :new, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    member = Content.get_ensemble_member!(id)
    render(conn, :edit, member: member, changeset: Content.change_ensemble_member(member))
  end

  def update(conn, %{"id" => id, "ensemble_member" => params}) do
    member = Content.get_ensemble_member!(id)

    case Content.update_ensemble_member(member, params) do
      {:ok, _} -> conn |> put_flash(:info, "Member updated.") |> redirect(to: ~p"/admin/ensemble")
      {:error, changeset} -> render(conn, :edit, member: member, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    member = Content.get_ensemble_member!(id)
    {:ok, _} = Content.delete_ensemble_member(member)
    conn |> put_flash(:info, "Member removed.") |> redirect(to: ~p"/admin/ensemble")
  end
end
