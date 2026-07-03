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
end
