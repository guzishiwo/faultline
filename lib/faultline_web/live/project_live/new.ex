defmodule FaultlineWeb.ProjectLive.New do
  use FaultlineWeb, :live_view

  alias Faultline.Projects
  alias Faultline.Projects.Project

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_form(socket, Projects.change_project(%Project{}))}
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    form =
      %Project{}
      |> Projects.change_project(project_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"project" => project_params}, socket) do
    case Projects.create_project(project_params, dsn_base_url: FaultlineWeb.Endpoint.url()) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{project.name} is ready for SDK events.")
         |> push_navigate(to: ~p"/projects")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto grid w-full max-w-5xl gap-8 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section class="space-y-6">
          <.link
            id="back-to-projects-link"
            navigate={~p"/projects"}
            class="inline-flex items-center gap-2 text-sm font-semibold text-base-content/60 transition hover:text-base-content"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Projects
          </.link>

          <div class="space-y-3">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-orange-600">
              New project
            </p>
            <h1 class="text-4xl font-semibold tracking-normal text-base-content sm:text-5xl">
              Generate a DSN for a service.
            </h1>
            <p class="max-w-2xl text-base leading-7 text-base-content/70">
              Name the service and set the first ingest limits. Faultline generates the public key, secret key, and DSN.
            </p>
          </div>

          <.form
            for={@form}
            id="project-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5 rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
          >
            <.input
              field={@form[:name]}
              type="text"
              label="Project name"
              placeholder="Web checkout"
              required
            />

            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@form[:rate_limit_max_events]}
                type="number"
                label="Max events"
                min="1"
                max="1000000"
                required
              />
              <.input
                field={@form[:rate_limit_window_seconds]}
                type="number"
                label="Window seconds"
                min="1"
                max="86400"
                required
              />
            </div>

            <div class="flex items-center justify-end gap-3 pt-2">
              <.link
                id="cancel-project-link"
                navigate={~p"/projects"}
                class="rounded-lg px-4 py-2.5 text-sm font-semibold text-base-content/60 transition hover:bg-base-200 hover:text-base-content"
              >
                Cancel
              </.link>
              <button
                id="save-project-button"
                type="submit"
                class="inline-flex items-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
              >
                <.icon name="hero-key" class="size-4" /> Create project
              </button>
            </div>
          </.form>
        </section>

        <aside class="rounded-lg border border-base-300 bg-base-200/70 p-5 text-sm leading-6 text-base-content/70 lg:mt-40">
          <p class="font-semibold text-base-content">DSN shape</p>
          <code class="mt-3 block overflow-x-auto rounded-md border border-base-300 bg-base-100 px-3 py-2 font-mono text-xs">
            https://public:secret@example.com/123
          </code>
          <p class="mt-4">
            The numeric path becomes the project id used by Sentry SDK ingest endpoints.
          </p>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
