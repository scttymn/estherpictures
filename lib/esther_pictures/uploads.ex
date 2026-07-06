defmodule EstherPictures.Uploads do
  @moduledoc """
  Stores user-uploaded files (currently clip thumbnails) under
  `priv/static/uploads`, which is served at `/uploads`.

  Files are saved with a random name (never the user-supplied name) to avoid
  path traversal and collisions. Returns the web path to store on the record.
  """

  @max_bytes 5 * 1_024 * 1_024
  @allowed %{
    "image/jpeg" => ".jpg",
    "image/png" => ".png",
    "image/webp" => ".webp",
    "image/gif" => ".gif"
  }

  @doc """
  Stores an uploaded image in `subdir` and returns `{:ok, "/uploads/<subdir>/<name>"}`.

  Returns `{:error, message}` for a non-image, an unsupported type, or a file
  that is too large.
  """
  def store_image(%Plug.Upload{} = upload, subdir) do
    with {:ok, ext} <- validate_type(upload),
         :ok <- validate_size(upload) do
      name = random_name() <> ext
      dir = dir_for(subdir)
      File.mkdir_p!(dir)
      File.cp!(upload.path, Path.join(dir, name))
      {:ok, "/uploads/#{subdir}/#{name}"}
    end
  end

  def store_image(_not_an_upload, _subdir), do: {:error, "No file was uploaded."}

  @doc "Web paths of every stored upload in `subdir`."
  def list(subdir) do
    case File.ls(dir_for(subdir)) do
      {:ok, names} -> Enum.map(names, &"/uploads/#{subdir}/#{&1}")
      {:error, _} -> []
    end
  end

  @doc "Deletes a previously stored upload given its web path. Best-effort."
  def delete(nil), do: :ok
  def delete(""), do: :ok

  def delete("/uploads/" <> rest) do
    path = Path.join(base_dir(), rest)
    # Guard against traversal: only delete inside the uploads dir.
    if String.starts_with?(Path.expand(path), Path.expand(base_dir())) do
      File.rm(path)
    end

    :ok
  end

  def delete(_other), do: :ok

  defp validate_type(%Plug.Upload{content_type: type}) do
    case Map.fetch(@allowed, type) do
      {:ok, ext} -> {:ok, ext}
      :error -> {:error, "Thumbnail must be a JPG, PNG, WebP, or GIF image."}
    end
  end

  defp validate_size(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= @max_bytes -> :ok
      {:ok, _} -> {:error, "Thumbnail must be 5 MB or smaller."}
      {:error, _} -> {:error, "Could not read the uploaded file."}
    end
  end

  defp random_name, do: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

  defp dir_for(subdir), do: Path.join(base_dir(), subdir)

  # Root is configured per-env (see config/config.exs and config/prod.exs).
  # In prod it's an absolute path on the VM's persistent volume; in dev it's
  # priv/static/uploads relative to the project root.
  defp base_dir do
    Application.get_env(:esther_pictures, __MODULE__)[:root] |> Path.expand()
  end
end
