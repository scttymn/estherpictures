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

  @doc """
  Player descriptor for a clip, used to fill the filmstrip's data-* attributes:

      %{kind: "youtube" | "vimeo" | "file" | "none",
        id: "<youtube video id>" | nil,
        muted: "<src>", unmuted: "<src>"}

  `muted`/`unmuted` are the chrome-less embed URLs (or the file URL) for each
  audio state. For YouTube the frontend drives audio through the IFrame Player
  API keyed by `id` instead; `muted`/`unmuted` remain the server-rendered and
  no-JS fallback sources. Vimeo/file still swap between the two URLs.
  """
  def clip_player(clip) do
    case reel_source(clip.video_url) do
      {:youtube, id} ->
        %{
          kind: "youtube",
          id: id,
          muted: youtube_embed_url(id, true),
          unmuted: youtube_embed_url(id, false)
        }

      {:vimeo, id} ->
        %{kind: "vimeo", id: nil, muted: vimeo_embed_url(id, true), unmuted: vimeo_embed_url(id, false)}

      {:file, url} ->
        %{kind: "file", id: nil, muted: url, unmuted: url}

      :none ->
        %{kind: "none", id: nil, muted: "", unmuted: ""}
    end
  end

  @doc "Chrome-less, looping embed URL for a YouTube id (muted or not)."
  def youtube_embed_url(id, muted?) do
    params =
      URI.encode_query(%{
        "autoplay" => 1,
        "mute" => (muted? && 1) || 0,
        "loop" => 1,
        "playlist" => id,
        "controls" => 0,
        "modestbranding" => 1,
        "rel" => 0,
        "playsinline" => 1,
        "iv_load_policy" => 3,
        "disablekb" => 1,
        "fs" => 0,
        # Lets the IFrame Player API adopt this server-rendered iframe so the
        # frontend can unmute/play in direct response to a tap (required for
        # sound playback on iOS, which forbids autoplaying unmuted media).
        "enablejsapi" => 1
      })

    "https://www.youtube-nocookie.com/embed/#{id}?#{params}"
  end

  @doc "Chrome-less, looping embed URL for a Vimeo id (muted or not)."
  def vimeo_embed_url(id, muted?) do
    base = %{
      "autoplay" => 1,
      "loop" => 1,
      "muted" => (muted? && 1) || 0,
      "controls" => 0,
      "title" => 0,
      "byline" => 0,
      "portrait" => 0
    }

    # `background=1` gives the cleanest chrome-less look but forces muting, so it
    # only applies to the muted state.
    params = if muted?, do: Map.put(base, "background", 1), else: base
    "https://player.vimeo.com/video/#{id}?#{URI.encode_query(params)}"
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
