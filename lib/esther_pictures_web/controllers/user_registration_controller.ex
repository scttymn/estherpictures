defmodule EstherPicturesWeb.UserRegistrationController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Accounts
  alias EstherPicturesWeb.UserAuth

  # This route only exists to create the very first account (the site
  # administrator). Once any account exists, registration is closed and
  # further accounts are created by an admin from /admin/users.
  def new(conn, _params) do
    if Accounts.any_users?() do
      registration_closed(conn)
    else
      render(conn, :new, changeset: Accounts.change_first_admin_registration())
    end
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_first_admin(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome — your administrator account is ready.")
        |> UserAuth.log_in_user(user, %{})

      {:error, :registration_closed} ->
        registration_closed(conn)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  defp registration_closed(conn) do
    conn
    |> put_flash(:error, "Registration is closed. Please log in.")
    |> redirect(to: ~p"/users/log-in")
  end
end
