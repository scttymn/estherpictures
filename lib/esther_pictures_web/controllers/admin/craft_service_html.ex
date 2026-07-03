defmodule EstherPicturesWeb.Admin.CraftServiceHTML do
  use EstherPicturesWeb, :html

  embed_templates "craft_service_html/*"

  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :submit_label, :string, default: "Save"

  def service_form(assigns) do
    ~H"""
    <.form :let={f} for={@changeset} as={:craft_service} action={@action} method={@method} class="space-y-4 max-w-lg">
      <.input field={f[:position]} type="number" label="Position (controls order & the 01–04 number)" />
      <.input field={f[:title]} label="Title" required />
      <.input field={f[:description]} type="textarea" label="Description" />
      <div class="flex gap-3">
        <.button class="btn btn-primary">{@submit_label}</.button>
        <.link href={~p"/admin/craft"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end
end
