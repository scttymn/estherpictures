defmodule EstherPicturesWeb.Admin.DashboardController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Content

  def index(conn, _params) do
    render(conn, :index,
      craft_count: length(Content.list_craft_services()),
      clip_count: length(Content.list_clips()),
      ensemble_count: length(Content.list_ensemble_members())
    )
  end
end
