defmodule EstherPicturesWeb.PageControllerTest do
  use EstherPicturesWeb.ConnCase

  test "GET / renders the public home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "ESTHER PICTURES"
    assert body =~ "01 REEL"
  end
end
