defmodule EstherPicturesWeb.Admin.EnsembleMemberHTML do
  use EstherPicturesWeb, :html

  embed_templates "ensemble_member_html/*"

  defdelegate bio_present?(bio), to: EstherPictures.Content.EnsembleMember

  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :submit_label, :string, default: "Save"
  attr :headshot, :string, default: nil

  def member_form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@changeset}
      as={:ensemble_member}
      action={@action}
      method={@method}
      multipart
      class="space-y-4 max-w-lg"
    >
      <.input field={f[:position]} type="number" label="Position (controls order & the A1/A2 code)" />
      <.input field={f[:name]} label="Name" required />
      <.input field={f[:role]} label="Role (e.g. DIRECTOR / ACTOR)" />
      <.input
        field={f[:bio]}
        type="textarea"
        label="Bio (optional — shown when a visitor expands the cast row)"
      />

      <div class="space-y-2">
        <label class="block text-sm font-semibold">Headshot</label>
        <div :if={@headshot && @headshot != ""} class="flex items-center gap-3">
          <img
            src={@headshot}
            alt="Current headshot"
            class="h-20 w-16 object-cover rounded border border-base-300"
          />
          <span class="text-sm opacity-60">Current headshot</span>
        </div>
        <input
          type="file"
          name="ensemble_member[headshot]"
          accept="image/*"
          class="file-input file-input-bordered w-full"
        />
        <p class="text-sm opacity-60">
          JPG, PNG, WebP, or GIF, up to 5&nbsp;MB. Shown left of the bio when
          a visitor expands the cast row. {if @headshot && @headshot != "",
            do: "Uploading a new image replaces the current one."}
        </p>
      </div>

      <.input field={f[:since_year]} label="Since year (e.g. 2021)" />
      <div class="flex gap-3">
        <.button class="btn btn-primary">{@submit_label}</.button>
        <.link href={~p"/admin/ensemble"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end
end
