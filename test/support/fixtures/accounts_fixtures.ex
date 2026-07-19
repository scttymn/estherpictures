defmodule EstherPictures.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `EstherPictures.Accounts` context.
  """

  import Ecto.Query

  alias EstherPictures.Accounts
  alias EstherPictures.Accounts.{Scope, User}
  alias EstherPictures.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "Hello world 123"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      role: "editor"
    })
  end

  @doc "Creates a confirmed, active user (default role editor)."
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      %User{}
      |> User.registration_changeset(valid_user_attributes(attrs))
      |> Repo.insert()

    user
  end

  @doc "Creates a confirmed admin user."
  def admin_user_fixture(attrs \\ %{}) do
    attrs |> Enum.into(%{role: "admin"}) |> user_fixture()
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Repo.update_all(
      from(t in Accounts.UserToken, where: t.token == ^token),
      set: [authenticated_at: authenticated_at]
    )
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
