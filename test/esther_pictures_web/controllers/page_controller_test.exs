defmodule EstherPicturesWeb.PageControllerTest do
  use EstherPicturesWeb.ConnCase

  alias EstherPictures.Content

  test "GET / renders the public home page", %{conn: conn} do
    # Phoenix's test conn defaults to host "www.example.com"; use a bare host so
    # the www -> apex canonical redirect doesn't intercept.
    conn = get(%{conn | host: "estherpictures.com"}, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "ESTHER PICTURES"
    assert body =~ "01 CLIPS"
  end

  test "GET / on www redirects to the apex host", %{conn: conn} do
    conn = get(%{conn | host: "www.estherpictures.com"}, ~p"/")
    assert redirected_to(conn, 301) == "https://estherpictures.com/"
  end

  test "cast rows with bio render as exclusive details accordion", %{conn: conn} do
    {:ok, with_bio} =
      Content.create_ensemble_member(%{
        "position" => 1,
        "name" => "Michael Joiner",
        "role" => "FOUNDER / ACTOR",
        "since_year" => "1991",
        "bio" => "A lifelong student of the craft."
      })

    {:ok, without_bio} =
      Content.create_ensemble_member(%{
        "position" => 2,
        "name" => "Mara Vance",
        "role" => "WRITER-DIRECTOR",
        "since_year" => "2019",
        "bio" => ""
      })

    conn = get(%{conn | host: "estherpictures.com"}, ~p"/")
    body = html_response(conn, 200)

    assert body =~ ~s(id="cast-member-#{with_bio.id}")
    assert body =~ "A lifelong student of the craft."
    assert body =~ "<details"
    assert body =~ "ep-member__bio"
    assert body =~ "ep-member__expand"
    assert body =~ "Show Bio"
    assert body =~ "Hide Bio"

    # Empty bio: plain row, no accordion shell for that member.
    refute body =~ ~s(id="cast-member-#{without_bio.id}")
    assert body =~ "Mara Vance"
  end

  test "cast bio panel shows headshot when present", %{conn: conn} do
    {:ok, with_shot} =
      Content.create_ensemble_member(%{
        "position" => 1,
        "name" => "Michael Joiner",
        "role" => "FOUNDER / ACTOR",
        "bio" => "A lifelong student of the craft.",
        "headshot_path" => "/uploads/cast/michael.jpg"
      })

    {:ok, no_shot} =
      Content.create_ensemble_member(%{
        "position" => 2,
        "name" => "Mara Vance",
        "role" => "WRITER-DIRECTOR",
        "bio" => "Writes and directs.",
        "headshot_path" => ""
      })

    conn = get(%{conn | host: "estherpictures.com"}, ~p"/")
    body = html_response(conn, 200)

    assert body =~ ~s(src="/uploads/cast/michael.jpg")
    assert body =~ "ep-member__headshot"
    assert body =~ ~s(id="cast-member-#{with_shot.id}")
    assert body =~ ~s(id="cast-member-#{no_shot.id}")
    # Only one headshot image (the member who has a path).
    assert length(Regex.scan(~r/ep-member__headshot/, body)) == 1
  end
end
