defmodule EstherPicturesWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use EstherPicturesWeb, :html

  embed_templates "page_html/*"

  @doc "Zero-pads a 1-based index to two digits: 1 -> \"01\"."
  def pad2(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc "Ensemble code for the Nth (1-based) member: 1 -> \"A1\"."
  def member_code(n), do: "A#{n}"

  @doc """
  Classifies a reel URL into an embeddable form:

    * `{:youtube, id}` — a YouTube watch/share/embed/shorts link
    * `{:vimeo, id}`   — a Vimeo link
    * `{:file, url}`   — a direct video file (mp4/webm/mov, or anything else)
    * `:none`          — blank

  Lets a non-developer paste whatever reel link they have.
  """
  def reel_source(url) when url in [nil, ""], do: :none

  def reel_source(url) do
    cond do
      id = youtube_id(url) -> {:youtube, id}
      id = vimeo_id(url) -> {:vimeo, id}
      true -> {:file, url}
    end
  end

  @doc "Chrome-less, muted, looping background embed URL for a YouTube id."
  def youtube_embed_url(id) do
    params =
      URI.encode_query(%{
        "autoplay" => 1,
        "mute" => 1,
        "loop" => 1,
        "playlist" => id,
        "controls" => 0,
        "modestbranding" => 1,
        "rel" => 0,
        "playsinline" => 1,
        "iv_load_policy" => 3,
        "disablekb" => 1,
        "fs" => 0
      })

    "https://www.youtube-nocookie.com/embed/#{id}?#{params}"
  end

  @doc "Chrome-less background embed URL for a Vimeo id."
  def vimeo_embed_url(id) do
    "https://player.vimeo.com/video/#{id}?" <>
      URI.encode_query(%{"background" => 1, "autoplay" => 1, "loop" => 1, "muted" => 1})
  end

  defp youtube_id(url) do
    regexes = [
      ~r"youtu\.be/([\w-]{11})",
      ~r"youtube(?:-nocookie)?\.com/watch\?(?:.*&)?v=([\w-]{11})",
      ~r"youtube(?:-nocookie)?\.com/embed/([\w-]{11})",
      ~r"youtube\.com/shorts/([\w-]{11})"
    ]

    Enum.find_value(regexes, fn re ->
      case Regex.run(re, url) do
        [_, id] -> id
        _ -> nil
      end
    end)
  end

  defp vimeo_id(url) do
    case Regex.run(~r"vimeo\.com/(?:video/)?(\d+)", url) do
      [_, id] -> id
      _ -> nil
    end
  end
end
