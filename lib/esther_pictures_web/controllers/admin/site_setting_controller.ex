defmodule EstherPicturesWeb.Admin.SiteSettingController do
  use EstherPicturesWeb, :controller

  alias EstherPictures.Content

  def edit(conn, _params) do
    setting = Content.get_site_settings()
    render(conn, :edit, changeset: Content.change_site_settings(setting))
  end

  def update(conn, %{"site_setting" => params}) do
    setting = Content.get_site_settings()

    case Content.update_site_settings(setting, params) do
      {:ok, _setting} ->
        conn
        |> put_flash(:info, "Site copy updated.")
        |> redirect(to: ~p"/admin/settings")

      {:error, changeset} ->
        render(conn, :edit, changeset: changeset)
    end
  end
end
