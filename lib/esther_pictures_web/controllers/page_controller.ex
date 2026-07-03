defmodule EstherPicturesWeb.PageController do
  use EstherPicturesWeb, :controller

  # The marketing site gets its own clean root layout (fonts + site.css),
  # isolated from the Tailwind/daisyUI admin styling.
  plug :put_root_layout, html: {EstherPicturesWeb.Layouts, :public_root}
  plug :put_layout, false

  def home(conn, _params) do
    render(conn, :home, data: EstherPictures.Content.home_page_data())
  end
end
