defmodule EstherPicturesWeb.Plugs.CanonicalHost do
  @moduledoc """
  Redirects `www.<host>` requests to the bare apex host with a 301, preserving
  the path and query string. Keeps a single canonical URL (estherpictures.com).
  """
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{host: "www." <> apex} = conn, _opts) do
    location = "https://" <> apex <> conn.request_path <> query(conn)

    conn
    |> put_resp_header("location", location)
    |> put_resp_content_type("text/plain")
    |> send_resp(301, "Moved Permanently\n")
    |> halt()
  end

  def call(conn, _opts), do: conn

  defp query(%Plug.Conn{query_string: ""}), do: ""
  defp query(%Plug.Conn{query_string: qs}), do: "?" <> qs
end
