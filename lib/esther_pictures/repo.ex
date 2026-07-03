defmodule EstherPictures.Repo do
  use Ecto.Repo,
    otp_app: :esther_pictures,
    adapter: Ecto.Adapters.SQLite3
end
