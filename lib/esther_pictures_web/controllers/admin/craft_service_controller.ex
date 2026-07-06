defmodule EstherPicturesWeb.Admin.CraftServiceController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Content
  alias EstherPictures.Content.CraftService

  def index(conn, _params) do
    render(conn, :index, services: Content.list_craft_services())
  end

  def new(conn, _params) do
    render(conn, :new, changeset: Content.change_craft_service(%CraftService{}))
  end

  def create(conn, %{"craft_service" => params}) do
    case Content.create_craft_service(params) do
      {:ok, _} ->
        conn |> put_flash(:info, "Service added.") |> redirect(to: ~p"/admin/craft")

      {:error, changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    service = Content.get_craft_service!(id)
    render(conn, :edit, service: service, changeset: Content.change_craft_service(service))
  end

  def update(conn, %{"id" => id, "craft_service" => params}) do
    service = Content.get_craft_service!(id)

    case Content.update_craft_service(service, params, conn.assigns.current_scope.user) do
      {:ok, _} ->
        conn |> put_flash(:info, "Service updated.") |> redirect(to: ~p"/admin/craft")

      {:error, changeset} ->
        render(conn, :edit, service: service, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    service = Content.get_craft_service!(id)
    {:ok, _} = Content.delete_craft_service(service, conn.assigns.current_scope.user)
    conn |> put_flash(:info, "Service removed.") |> redirect(to: ~p"/admin/craft")
  end
end
