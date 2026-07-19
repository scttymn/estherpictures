defmodule EstherPicturesWeb.Admin.ClipHTML do
  use EstherPicturesWeb, :html

  embed_templates "clip_html/*"

  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :submit_label, :string, default: "Save"
  attr :thumbnail, :string, default: nil

  def clip_form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@changeset}
      as={:clip}
      action={@action}
      method={@method}
      multipart
      class="space-y-5 max-w-lg"
    >
      <.input
        field={f[:position]}
        type="number"
        label="Position (controls order & the CLIP 0X number)"
      />
      <.input field={f[:title]} label="Title" required />
      <.input
        field={f[:video_url]}
        label="Video URL — YouTube or Vimeo (blank shows a placeholder)"
      />

      <fieldset class="border border-base-300 rounded-lg p-4 space-y-4">
        <legend class="px-1 text-sm opacity-70">Slate stats (shown while this clip plays)</legend>
        <div class="grid sm:grid-cols-2 gap-4">
          <.input field={f[:runtime]} label="Runtime" />
          <.input field={f[:format]} label="Format" />
          <.input field={f[:years]} label="Years" />
          <.input field={f[:status]} label="Status" />
        </div>
      </fieldset>

      <div class="space-y-2">
        <label class="block text-sm font-semibold">Thumbnail image</label>
        <div :if={@thumbnail && @thumbnail != ""} class="flex items-center gap-3">
          <img
            src={@thumbnail}
            alt="Current thumbnail"
            class="h-16 w-28 object-cover rounded border border-base-300"
          />
          <span class="text-sm opacity-60">Current thumbnail</span>
        </div>
        <input
          type="file"
          name="clip[thumbnail]"
          accept="image/*"
          class="file-input file-input-bordered w-full"
        />
        <p class="text-sm opacity-60">
          JPG, PNG, WebP, or GIF, up to 5&nbsp;MB. Since YouTube can't export a
          frame at a chosen time, upload the still you want here. {if @thumbnail && @thumbnail != "",
            do: "Uploading a new image replaces the current one."}
        </p>
      </div>

      <div class="flex gap-3">
        <.button class="btn btn-primary">{@submit_label}</.button>
        <.link href={~p"/admin/clips"} class="btn btn-ghost">Cancel</.link>
      </div>
    </.form>
    """
  end
end
