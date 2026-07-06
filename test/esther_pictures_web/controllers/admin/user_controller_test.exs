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
      assert is_binary(temp_password) and byte_size(temp_password) >= 12

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
end
