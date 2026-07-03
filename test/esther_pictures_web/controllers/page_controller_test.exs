defmodule EstherPicturesWeb.PageControllerTest do
  use EstherPicturesWeb.ConnCase

  test "GET / renders the public home page", %{conn: conn} do
    # Phoenix's test conn defaults to host "www.example.com"; use a bare host so
    # the www -> apex canonical redirect doesn't intercept.
    conn = get(%{conn | host: "estherpictures.com"}, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "ESTHER PICTURES"
    assert body =~ "01 SHOWCASE"
  end

  test "GET / on www redirects to the apex host", %{conn: conn} do
    conn = get(%{conn | host: "www.estherpictures.com"}, ~p"/")
    assert redirected_to(conn, 301) == "https://estherpictures.com/"
  end
end
