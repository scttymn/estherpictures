defmodule EstherPicturesWeb.Plugs.Health do
  @moduledoc """
  Answers `GET /up` with 200 "ok" on any host, before the canonical-host
  redirect, sessions or the database: Houston's health check before it switches
  traffic to a new version. Every other request passes through.
  """
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/up"} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
