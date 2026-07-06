defmodule EstherPicturesWeb.Admin.UserController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Accounts

  def index(conn, _params) do
    render(conn, :index,
      users: Accounts.list_users(),
      current_user: conn.assigns.current_scope.user
    )
  end

  def new(conn, _params) do
    render(conn, :new, changeset: Accounts.change_editor())
  end

  def create(conn, %{"user" => user_params}) do
    temp_password = Accounts.generate_temp_password()

    attrs = Map.merge(user_params, %{"password" => temp_password})

    case Accounts.create_editor(attrs) do
      {:ok, user} ->
        conn
        |> put_flash(:temp_password, temp_password)
        |> put_flash(:temp_password_email, user.email)
        |> redirect(to: ~p"/admin/users")

      {:error, changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    current = conn.assigns.current_scope.user

    cond do
      user.id == current.id ->
        conn
        |> put_flash(:error, "You can't delete your own account.")
        |> redirect(to: ~p"/admin/users")

      true ->
        {:ok, _} = Accounts.delete_user(user)

        conn
        |> put_flash(:info, "Removed #{user.email}.")
        |> redirect(to: ~p"/admin/users")
    end
  end
end
