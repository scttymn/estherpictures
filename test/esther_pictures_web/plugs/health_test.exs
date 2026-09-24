defmodule EstherPicturesWeb.Plugs.HealthTest do
  use EstherPicturesWeb.ConnCase, async: true

  test "GET /up answers 200 ok", %{conn: conn} do
    conn = get(conn, "/up")
    assert conn.status == 200
    assert conn.resp_body == "ok"
  end

  test "/up answers on www too, before the canonical-host redirect", %{conn: conn} do
    conn = get(%{conn | host: "www.estherpictures.com"}, "/up")
    assert conn.status == 200
  end

  test "other paths on www still redirect to the apex", %{conn: conn} do
    conn = get(%{conn | host: "www.estherpictures.com"}, "/about?x=1")
    assert conn.status == 301
    assert get_resp_header(conn, "location") == ["https://estherpictures.com/about?x=1"]
  end
end
