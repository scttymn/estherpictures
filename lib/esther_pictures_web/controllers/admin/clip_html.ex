defmodule EstherPicturesWeb.Admin.ClipHTML do
  use EstherPicturesWeb, :html

  embed_templates "clip_html/*"

  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :submit_label, :string, default: "Save"

  def clip_form(assigns) do
    ~H"""
    <.form :let={f} for={@changeset} as={:clip} action={@action} method={@method} class="space-y-4 max-w-lg">
      <.input field={f[:position]} type="number" label="Position (controls order & the CLIP 0X number)" />
      <.input field={f[:title]} label="Title" required />
      <div class="flex gap-3">
        <.button class="btn btn-primary">{@submit_label}</.button>
        <.link href={~p"/admin/clips"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end
end
