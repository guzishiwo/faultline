defmodule FaultlineWeb.ProjectLive.Index do
  use FaultlineWeb, :live_view

  alias Faultline.Projects

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects()

    {:ok,
     socket
     |> stream(:projects, projects)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto w-full max-w-6xl space-y-8">
        <section class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_20rem] lg:items-end">
          <div class="space-y-4">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-orange-600">
              Faultline Projects
            </p>
            <div class="space-y-3">
              <h1 class="text-4xl font-semibold tracking-normal text-base-content sm:text-5xl">
                Route SDK errors into a project DSN.
              </h1>
              <p class="max-w-2xl text-base leading-7 text-base-content/70">
                Create a project, copy the Sentry-compatible DSN, and keep per-project ingest limits close to the key that clients use.
              </p>
            </div>
          </div>
          <div class="flex lg:justify-end">
            <.link
              id="new-project-link"
              navigate={~p"/projects/new"}
              class="inline-flex items-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
            >
              <.icon name="hero-plus" class="size-4" /> New project
            </.link>
          </div>
        </section>

        <section class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm">
          <div class="border-b border-base-300 px-5 py-4">
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Project registry
            </h2>
          </div>

          <div id="projects" phx-update="stream" class="divide-y divide-base-300">
            <div id="projects-empty-state" class="hidden px-5 py-12 text-center only:block">
              <div class="mx-auto flex max-w-sm flex-col items-center gap-4">
                <div class="rounded-full bg-orange-100 p-3 text-orange-700">
                  <.icon name="hero-key" class="size-6" />
                </div>
                <div>
                  <p class="font-semibold text-base-content">No projects yet</p>
                  <p class="mt-1 text-sm leading-6 text-base-content/60">
                    Add the first project to generate a DSN for an SDK.
                  </p>
                </div>
              </div>
            </div>

            <article
              :for={{id, project} <- @streams.projects}
              id={id}
              class="grid gap-5 px-5 py-5 transition hover:bg-base-200/60 lg:grid-cols-[minmax(12rem,18rem)_minmax(0,1fr)_12rem]"
            >
              <div class="min-w-0">
                <p class="truncate text-base font-semibold text-base-content">{project.name}</p>
                <p class="mt-1 font-mono text-xs text-base-content/50">{project.slug}</p>
              </div>

              <div class="min-w-0">
                <label class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
                  DSN
                </label>
                <code class="mt-2 block overflow-x-auto rounded-md border border-base-300 bg-base-200 px-3 py-2 font-mono text-xs text-base-content">
                  {project.dsn}
                </code>
              </div>

              <div class="flex flex-col justify-center gap-1 text-sm text-base-content/70">
                <p>
                  <span class="font-semibold text-base-content">{project.rate_limit_max_events}</span>
                  events
                </p>
                <p>per {project.rate_limit_window_seconds}s</p>
                <.link
                  id={"project-issues-link-#{project.id}"}
                  navigate={~p"/projects/#{project.id}/issues"}
                  class="mt-2 inline-flex items-center gap-1 font-semibold text-base-content transition hover:text-orange-600"
                >
                  Issues <.icon name="hero-arrow-right" class="size-3" />
                </.link>
              </div>
            </article>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
