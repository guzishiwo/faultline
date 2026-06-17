defmodule FaultlineWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FaultlineWeb, :html

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
    ~H"""
    <header class="sticky top-0 z-30 border-b border-base-300 bg-base-100/95 backdrop-blur">
      <div class="px-4 sm:px-6 lg:px-8">
        <div class="mx-auto flex h-14 max-w-7xl items-center gap-3">
          <a id="app-home-link" href="/" class="flex min-w-0 items-center gap-2.5">
            <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-base-content text-xs font-bold text-base-100 shadow-sm">
              F
            </span>
            <span class="truncate text-sm font-semibold tracking-normal">Faultline</span>
          </a>

          <nav
            :if={@current_scope && @current_scope.user}
            id="app-primary-nav"
            class="ml-auto hidden items-center rounded-full border border-base-300 bg-base-200/60 p-1 shadow-sm sm:flex"
          >
            <.link
              navigate={~p"/issues?project=-1"}
              class="rounded-full px-3 py-1.5 text-sm font-semibold leading-none transition hover:bg-base-100 hover:shadow-sm"
            >
              Issues
            </.link>
            <.link
              navigate={~p"/projects"}
              class="rounded-full px-3 py-1.5 text-sm font-semibold leading-none transition hover:bg-base-100 hover:shadow-sm"
            >
              Projects
            </.link>
            <.link
              :if={@current_scope.user.role == "admin"}
              navigate={~p"/admin/settings"}
              class="rounded-full px-3 py-1.5 text-sm font-semibold leading-none transition hover:bg-base-100 hover:shadow-sm"
            >
              Admin
            </.link>
          </nav>

          <div class={[
            "flex items-center gap-1.5",
            @current_scope && @current_scope.user && "ml-auto sm:ml-0",
            !(@current_scope && @current_scope.user) && "ml-auto"
          ]}>
            <.theme_toggle />
            <.account_menu current_scope={@current_scope} />

            <.link
              :if={!@current_scope || !@current_scope.user}
              navigate={~p"/users/log-in"}
              class="rounded-lg px-3 py-2 text-sm font-semibold transition hover:bg-base-200"
            >
              Log in
            </.link>
            <.link
              :if={!@current_scope || !@current_scope.user}
              navigate={~p"/users/register"}
              class="rounded-lg bg-base-content px-3 py-2 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
            >
              Register
            </.link>
          </div>
        </div>
      </div>
    </header>

    <main class="px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-7xl space-y-4">
        {render_slot(@inner_block)}
      </div>
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
    <details
      class="group relative"
      data-close-on-click-away
      phx-click-away={JS.remove_attribute("open")}
      phx-window-keydown={JS.remove_attribute("open")}
      phx-key="escape"
    >
      <summary
        id="theme-menu-trigger"
        class="flex size-9 cursor-pointer list-none items-center justify-center rounded-lg border border-base-300 bg-base-100 text-base-content/70 shadow-sm transition hover:-translate-y-0.5 hover:text-base-content hover:shadow-md [&::-webkit-details-marker]:hidden"
        aria-label="Theme"
      >
        <.icon name="hero-sun-micro" class="size-4 dark:hidden" />
        <.icon name="hero-moon-micro" class="hidden size-4 dark:block" />
      </summary>

      <div
        id="theme-menu"
        class="absolute right-0 z-40 mt-2 w-44 overflow-hidden rounded-lg border border-base-300 bg-base-100 p-1 shadow-xl"
      >
        <button
          class="flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm font-semibold transition hover:bg-base-200"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme="system"
        >
          <.icon name="hero-computer-desktop-micro" class="size-4 text-base-content/60" /> System
        </button>
        <button
          class="flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm font-semibold transition hover:bg-base-200"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme="light"
        >
          <.icon name="hero-sun-micro" class="size-4 text-base-content/60" /> Light
        </button>
        <button
          class="flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm font-semibold transition hover:bg-base-200"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme="dark"
        >
          <.icon name="hero-moon-micro" class="size-4 text-base-content/60" /> Dark
        </button>
      </div>
    </details>
    """
  end

  attr :current_scope, :map, default: nil

  def account_menu(assigns) do
    ~H"""
    <details
      :if={@current_scope && @current_scope.user}
      class="group relative"
      data-close-on-click-away
      phx-click-away={JS.remove_attribute("open")}
      phx-window-keydown={JS.remove_attribute("open")}
      phx-key="escape"
    >
      <summary
        id="account-menu-trigger"
        class="flex size-9 cursor-pointer list-none items-center justify-center rounded-lg border border-base-300 bg-base-content text-xs font-bold uppercase text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md [&::-webkit-details-marker]:hidden"
        aria-label="Account menu"
      >
        {user_initial(@current_scope.user)}
      </summary>

      <div
        id="account-menu"
        class="absolute right-0 z-40 mt-2 w-60 overflow-hidden rounded-lg border border-base-300 bg-base-100 p-1 shadow-xl"
      >
        <div class="px-3 py-2">
          <p class="truncate text-sm font-semibold text-base-content">
            {@current_scope.user.email}
          </p>
          <p class="mt-0.5 text-xs uppercase tracking-[0.14em] text-base-content/50">
            {@current_scope.user.role}
          </p>
        </div>

        <div class="h-px bg-base-300" />

        <div class="py-1 sm:hidden">
          <.link
            navigate={~p"/issues?project=-1"}
            class="flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition hover:bg-base-200"
          >
            <.icon name="hero-inbox-stack" class="size-4 text-base-content/60" /> Issues
          </.link>
          <.link
            navigate={~p"/projects"}
            class="flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition hover:bg-base-200"
          >
            <.icon name="hero-briefcase" class="size-4 text-base-content/60" /> Projects
          </.link>
          <.link
            :if={@current_scope.user.role == "admin"}
            navigate={~p"/admin/settings"}
            class="flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition hover:bg-base-200"
          >
            <.icon name="hero-shield-check" class="size-4 text-base-content/60" /> Admin
          </.link>
        </div>

        <div class="h-px bg-base-300 sm:hidden" />

        <div class="py-1">
          <.link
            id="account-settings-link"
            href={~p"/users/settings"}
            class="flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition hover:bg-base-200"
          >
            <.icon name="hero-cog-6-tooth" class="size-4 text-base-content/60" /> Settings
          </.link>
          <.link
            href={~p"/users/log-out"}
            method="delete"
            class="flex items-center gap-2 rounded-md px-3 py-2 text-sm font-semibold text-red-600 transition hover:bg-red-50 dark:hover:bg-red-950/30"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Log out
          </.link>
        </div>
      </div>
    </details>
    """
  end

  defp user_initial(user) do
    user.email
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "U"
      first -> String.upcase(first)
    end
  end
end
