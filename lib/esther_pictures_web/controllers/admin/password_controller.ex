defmodule EstherPicturesWeb.Admin.PasswordController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Accounts
  alias EstherPicturesWeb.UserAuth

  def edit(conn, _params) do
    user = conn.assigns.current_scope.user

    render(conn, :edit,
      changeset: Accounts.change_user_password(user),
      forced: user.must_change_password
    )
  end

  def update(conn, %{"user" => user_params}) do
    user = conn.assigns.current_scope.user

    case Accounts.update_user_password(user, user_params) do
      {:ok, {user, _expired_tokens}} ->
        conn
        |> put_flash(:info, "Password updated.")
        |> put_session(:user_return_to, ~p"/admin")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit, changeset: changeset, forced: user.must_change_password)
    end
  end
end
