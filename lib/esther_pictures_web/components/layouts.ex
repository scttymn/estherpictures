defmodule EstherPicturesWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use EstherPicturesWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    user = assigns[:current_scope] && assigns.current_scope.user
    assigns = assign(assigns, user: user, is_admin: user && user.role == "admin")

    ~H"""
    <header class="border-b border-base-300">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 flex items-center gap-4 h-16">
        <a
          href={if @user, do: ~p"/admin", else: ~p"/"}
          class="font-black tracking-tight text-lg whitespace-nowrap shrink-0"
        >
          ESTHER PICTURES <span class="font-normal text-base-content/50 text-sm">· ADMIN</span>
        </a>

        <nav :if={@user} class="hidden md:flex items-center gap-1 text-sm">
          <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm">Dashboard</.link>
          <.link navigate={~p"/admin/settings"} class="btn btn-ghost btn-sm">Site copy</.link>
          <.link navigate={~p"/admin/craft"} class="btn btn-ghost btn-sm">Craft</.link>
          <.link navigate={~p"/admin/clips"} class="btn btn-ghost btn-sm">Clips</.link>
          <.link navigate={~p"/admin/ensemble"} class="btn btn-ghost btn-sm">Ensemble</.link>
          <.link :if={@is_admin} navigate={~p"/admin/users"} class="btn btn-ghost btn-sm">Users</.link>
        </nav>

        <div class="ml-auto flex items-center gap-3 text-sm shrink-0">
          <a href={~p"/"} class="link link-hover opacity-70 whitespace-nowrap">View site ↗</a>
          <%= if @user do %>
            <span class="hidden lg:inline opacity-60 whitespace-nowrap">{@user.email}</span>
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="btn btn-ghost btn-sm whitespace-nowrap"
            >
              Log out
            </.link>
          <% end %>
        </div>
      </div>
    </header>

    <main class="mx-auto max-w-5xl px-4 sm:px-6 py-10">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Minimal chrome for authentication pages (log in, first-run setup, forced
  password change). Deliberately does NOT render the admin navigation — those
  pages must not expose or imply admin access.
  """
  attr :flash, :map, required: true

  attr :current_scope, :map,
    default: nil,
    doc: "accepted for call-site symmetry; unused here"

  slot :inner_block, required: true

  def auth(assigns) do
    ~H"""
    <header class="border-b border-base-300">
      <div class="mx-auto max-w-5xl px-4 sm:px-6 h-16 flex items-center">
        <a href={~p"/"} class="font-black tracking-tight text-lg">
          ESTHER PICTURES <span class="font-normal text-base-content/50 text-sm">· ADMIN</span>
        </a>
      </div>
    </header>

    <main class="mx-auto max-w-md px-4 sm:px-6 py-16">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
