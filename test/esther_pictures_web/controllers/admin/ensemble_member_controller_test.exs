defmodule EstherPicturesWeb.Admin.EnsembleMemberControllerTest do
  # Not async: file uploads + SQLite writer.
  use EstherPicturesWeb.ConnCase, async: false

  import EstherPictures.AccountsFixtures

  alias EstherPictures.Content

  setup %{conn: conn} do
    admin = admin_user_fixture()
    conn = %{conn | host: "estherpictures.com"}
    %{conn: log_in_user(conn, admin)}
  end

  defp image_upload(name \\ "headshot.jpg") do
    path = Path.join(System.tmp_dir!(), "ep-test-#{System.unique_integer([:positive])}.jpg")
    File.write!(path, <<0xFF, 0xD8, 0xFF, 0xD9>>)

    on_exit(fn -> File.rm(path) end)

    %Plug.Upload{
      path: path,
      filename: name,
      content_type: "image/jpeg"
    }
  end

  test "POST /admin/ensemble stores an uploaded headshot", %{conn: conn} do
    conn =
      post(conn, ~p"/admin/ensemble",
        ensemble_member: %{
          "name" => "Michael Joiner",
          "role" => "FOUNDER / ACTOR",
          "since_year" => "1991",
          "bio" => "A lifelong student.",
          "position" => "1",
          "headshot" => image_upload()
        }
      )

    assert redirected_to(conn) == ~p"/admin/ensemble"

    [member] = Content.list_ensemble_members()
    assert member.name == "Michael Joiner"
    assert member.headshot_path =~ ~r"^/uploads/cast/"

    assert File.exists?(
             Path.join(
               Application.get_env(:esther_pictures, EstherPictures.Uploads)[:root],
               String.trim_leading(member.headshot_path, "/uploads/")
             )
           )
  end

  test "POST /admin/ensemble without headshot leaves path blank", %{conn: conn} do
    conn =
      post(conn, ~p"/admin/ensemble",
        ensemble_member: %{
          "name" => "Mara Vance",
          "role" => "WRITER-DIRECTOR",
          "bio" => "",
          "position" => "1"
        }
      )

    assert redirected_to(conn) == ~p"/admin/ensemble"
    [member] = Content.list_ensemble_members()
    assert member.headshot_path in [nil, ""]
  end
end
