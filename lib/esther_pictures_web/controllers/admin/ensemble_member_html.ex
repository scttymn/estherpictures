defmodule EstherPicturesWeb.Admin.EnsembleMemberHTML do
  use EstherPicturesWeb, :html

  embed_templates "ensemble_member_html/*"

  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :submit_label, :string, default: "Save"

  def member_form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@changeset}
      as={:ensemble_member}
      action={@action}
      method={@method}
      class="space-y-4 max-w-lg"
    >
      <.input field={f[:position]} type="number" label="Position (controls order & the A1/A2 code)" />
      <.input field={f[:name]} label="Name" required />
      <.input field={f[:role]} label="Role (e.g. DIRECTOR / ACTOR)" />
      <.input field={f[:since_year]} label="Since year (e.g. 2021)" />
      <.input
        field={f[:bio]}
        type="textarea"
        label="Bio (optional — shown when a visitor expands the cast row)"
      />
      <div class="flex gap-3">
        <.button class="btn btn-primary">{@submit_label}</.button>
        <.link href={~p"/admin/ensemble"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end
end
