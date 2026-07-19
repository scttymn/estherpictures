defmodule EstherPicturesWeb.Admin.UserControllerTest do
  use EstherPicturesWeb.ConnCase, async: true

  import EstherPictures.AccountsFixtures

  setup %{conn: conn} do
    admin = admin_user_fixture()
    # Phoenix's test conn defaults to host "www.example.com"; use a bare host so
    # the www -> apex canonical redirect doesn't intercept.
    conn = %{conn | host: "estherpictures.com"}
    %{conn: log_in_user(conn, admin), admin: admin}
  end

  describe "POST /admin/users" do
    test "shows the temp password in a modal after creating an editor", %{conn: conn} do
      conn = post(conn, ~p"/admin/users", user: %{"email" => "newbie@example.com"})
      assert redirected_to(conn) == ~p"/admin/users"

      temp_password = Phoenix.Flash.get(conn.assigns.flash, :temp_password)
      assert temp_password =~ ~r/^\d{7}$/
      assert Phoenix.Flash.get(conn.assigns.flash, :temp_password_kind) == "created"

      html = conn |> get(~p"/admin/users") |> html_response(200)
      assert html =~ "Account created for newbie@example.com"
      assert html =~ temp_password
      assert html =~ ~s(data-copy="#{temp_password}")
    end

    test "does not render the modal on a plain visit", %{conn: conn} do
      html = conn |> get(~p"/admin/users") |> html_response(200)
      refute html =~ "Account created for"
    end
  end

  describe "POST /admin/users/:id/reset-password" do
    test "resets another user's password and shows the temp password", %{conn: conn} do
      editor = user_fixture(%{email: "editor@example.com"})

      conn = post(conn, ~p"/admin/users/#{editor}/reset-password")
      assert redirected_to(conn) == ~p"/admin/users"

      temp_password = Phoenix.Flash.get(conn.assigns.flash, :temp_password)
      assert temp_password =~ ~r/^\d{7}$/
      assert Phoenix.Flash.get(conn.assigns.flash, :temp_password_kind) == "reset"
      assert Phoenix.Flash.get(conn.assigns.flash, :temp_password_email) == "editor@example.com"

      html = conn |> get(~p"/admin/users") |> html_response(200)
      assert html =~ "Password reset for editor@example.com"
      assert html =~ temp_password

      editor = EstherPictures.Accounts.get_user!(editor.id)
      assert editor.must_change_password

      assert EstherPictures.Accounts.get_user_by_email_and_password(
               "editor@example.com",
               temp_password
             )
    end

    test "does not allow resetting your own password", %{conn: conn, admin: admin} do
      conn = post(conn, ~p"/admin/users/#{admin}/reset-password")
      assert redirected_to(conn) == ~p"/admin/users"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "own password"
      refute Phoenix.Flash.get(conn.assigns.flash, :temp_password)
    end
  end
end
