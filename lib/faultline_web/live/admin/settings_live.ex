defmodule FaultlineWeb.Admin.SettingsLive do
  use FaultlineWeb, :live_view

  alias Faultline.InstanceSettings
  alias Faultline.Projects

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_settings(socket)}
  end

  @impl true
  def handle_event("validate_public_dsn_base_url", %{"instance_settings" => params}, socket) do
    changeset =
      params
      |> InstanceSettings.change_public_dsn_base_url()
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save_public_dsn_base_url", %{"instance_settings" => params}, socket) do
    case InstanceSettings.update_public_dsn_base_url(params) do
      {:ok, _settings} ->
        {:noreply,
         socket
         |> put_flash(:info, "Public DSN base URL updated.")
         |> assign_settings()}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :update))}
    end
  end

  def handle_event("regenerate_project_dsns", _params, socket) do
    case Projects.regenerate_all_project_dsns() do
      {:ok, count} ->
        {:noreply,
         socket
         |> put_flash(:info, "Regenerated #{count} #{project_label(count)}.")
         |> assign_settings()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not regenerate project DSNs.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="admin-instance-settings-page" class="mx-auto w-full max-w-7xl space-y-6">
        <header class="flex flex-col gap-4 border-b border-base-300 pb-5 lg:flex-row lg:items-end lg:justify-between">
          <div class="min-w-0">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
              Admin
            </p>
            <h1 class="mt-2 text-3xl font-semibold tracking-normal text-base-content">
              Instance settings
            </h1>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-base-content/60">
              Configure the public address SDKs use to send events into this Faultline instance.
            </p>
          </div>

          <.link
            id="admin-users-link"
            navigate={~p"/admin/users"}
            class="inline-flex w-fit items-center gap-2 rounded-lg border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content/70 transition hover:-translate-y-0.5 hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-users" class="size-4" /> Users
          </.link>
        </header>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
          <section
            id="public-dsn-base-url-card"
            class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
          >
            <div class="flex items-start gap-3">
              <div class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                <.icon name="hero-globe-alt" class="size-5" />
              </div>
              <div class="min-w-0">
                <h2 class="text-lg font-semibold text-base-content">Public DSN base URL</h2>
                <p class="mt-1 text-sm leading-6 text-base-content/60">
                  Use the externally reachable HTTPS origin. New projects embed this origin in generated SDK DSNs.
                </p>
              </div>
            </div>

            <div class="mt-5 rounded-lg border border-base-300 bg-base-200/45 px-4 py-3">
              <p class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/45">
                Current
              </p>
              <p id="current-public-dsn-base-url" class="mt-1 break-all font-mono text-sm">
                {@public_dsn_base_url}
              </p>
            </div>

            <.form
              for={@form}
              id="public-dsn-base-url-form"
              phx-change="validate_public_dsn_base_url"
              phx-submit="save_public_dsn_base_url"
              class="mt-5 space-y-4"
            >
              <.input
                field={@form[:public_dsn_base_url]}
                type="url"
                label="Public DSN base URL"
                placeholder="https://errors.example.com"
                required
              />
              <button
                id="save-public-dsn-base-url-button"
                type="submit"
                class="inline-flex items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
              >
                <.icon name="hero-check" class="size-4" /> Save public URL
              </button>
            </.form>
          </section>

          <aside class="h-fit space-y-4 rounded-lg border border-base-300 bg-base-200/70 p-5 text-sm leading-6 text-base-content/70">
            <div>
              <p class="font-semibold text-base-content">Docker and Fly.io</p>
              <p class="mt-2">
                At boot, Faultline uses <code class="font-mono">PHX_HOST</code>
                as the default public DSN host. This page overrides that value without rebuilding the container.
              </p>
            </div>

            <div class="border-t border-base-300 pt-4">
              <p class="font-semibold text-base-content">Existing projects</p>
              <p class="mt-2">
                Projects keep the DSN generated at creation time. Regenerate them after changing domains.
              </p>
              <button
                id="regenerate-project-dsns-button"
                type="button"
                phx-click="regenerate_project_dsns"
                data-confirm="Regenerate DSNs for all projects using the current public base URL?"
                class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-lg border border-base-300 bg-base-100 px-4 py-2.5 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
              >
                <.icon name="hero-arrow-path" class="size-4" /> Regenerate project DSNs
              </button>
            </div>
          </aside>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp assign_settings(socket) do
    socket
    |> assign(:public_dsn_base_url, InstanceSettings.public_dsn_base_url())
    |> assign_form(InstanceSettings.change_public_dsn_base_url())
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: :instance_settings))
  end

  defp project_label(1), do: "project DSN"
  defp project_label(_count), do: "project DSNs"
end
