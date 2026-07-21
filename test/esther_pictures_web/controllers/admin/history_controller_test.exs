defmodule EstherPicturesWeb.Admin.HistoryControllerTest do
  # Not async: SQLite allows a single writer, and these tests write heavily.
  use EstherPicturesWeb.ConnCase, async: false

  import EstherPictures.AccountsFixtures

  alias EstherPictures.Content

  # Phoenix's test conn defaults to host "www.example.com"; use a bare host so
  # the www -> apex canonical redirect doesn't intercept.
  defp bare_host(conn), do: %{conn | host: "estherpictures.com"}

  setup %{conn: conn} do
    %{conn: bare_host(conn)}
  end

  test "editors are turned away from every history action", %{conn: conn} do
    {:ok, member} = Content.create_ensemble_member(%{"name" => "Cleo Nakamura"})
    {:ok, _} = Content.update_ensemble_member(member, %{"name" => "Typo"})
    [version] = Content.list_versions()

    conn = log_in_user(conn, user_fixture())

    for request <- [
          get(conn, ~p"/admin/history"),
          post(conn, ~p"/admin/history/#{version.id}/restore"),
          delete(conn, ~p"/admin/history/#{version.id}"),
          delete(conn, ~p"/admin/history")
        ] do
      assert redirected_to(request) == ~p"/admin"
    end

    # Nothing was restored or discarded.
    assert Content.get_ensemble_member!(member.id).name == "Typo"
    assert [_] = Content.list_versions()
  end

  test "admin sees history and can restore an edit", %{conn: conn} do
    conn = log_in_user(conn, admin_user_fixture())

    {:ok, member} = Content.create_ensemble_member(%{"name" => "Cleo Nakamura"})
    {:ok, _} = Content.update_ensemble_member(member, %{"name" => "Wrong Name"})

    html = conn |> get(~p"/admin/history") |> html_response(200)
    assert html =~ "Cast member"
    assert html =~ "Cleo Nakamura"

    [version] = Content.list_versions()
    conn = post(conn, ~p"/admin/history/#{version.id}/restore")
    assert redirected_to(conn) == ~p"/admin/history"

    assert Content.get_ensemble_member!(member.id).name == "Cleo Nakamura"
  end

  test "admin can discard a single history entry", %{conn: conn} do
    conn = log_in_user(conn, admin_user_fixture())

    {:ok, member} = Content.create_ensemble_member(%{"name" => "Cleo Nakamura"})
    {:ok, _} = Content.update_ensemble_member(member, %{"name" => "Keep me"})
    {:ok, _} = Content.update_ensemble_member(member, %{"name" => "Discard me"})

    [newest, oldest] = Content.list_versions()
    conn = delete(conn, ~p"/admin/history/#{newest.id}")
    assert redirected_to(conn) == ~p"/admin/history"

    assert [%{id: remaining_id}] = Content.list_versions()
    assert remaining_id == oldest.id
  end

  test "admin can clear all history", %{conn: conn} do
    conn = log_in_user(conn, admin_user_fixture())

    {:ok, member} = Content.create_ensemble_member(%{"name" => "Cleo Nakamura"})
    {:ok, _} = Content.update_ensemble_member(member, %{"name" => "Typo"})
    assert Content.list_versions() != []

    conn = delete(conn, ~p"/admin/history")
    assert redirected_to(conn) == ~p"/admin/history"
    assert Content.list_versions() == []
  end

  test "admin can bring back a deleted record", %{conn: conn} do
    conn = log_in_user(conn, admin_user_fixture())

    {:ok, service} = Content.create_craft_service(%{"title" => "Color Grading"})
    {:ok, _} = Content.delete_craft_service(service)

    [version] = Content.list_versions()
    post(conn, ~p"/admin/history/#{version.id}/restore")

    assert Content.get_craft_service!(service.id).title == "Color Grading"
  end
end
