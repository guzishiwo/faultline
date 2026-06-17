defmodule FaultlineWeb.ProjectLive.Index do
  use FaultlineWeb, :live_view

  alias Faultline.Projects

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects()

    {:ok,
     socket
     |> assign(:project_count, length(projects))
     |> stream(:projects, projects)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-7xl space-y-6">
        <section class="flex flex-col gap-4 border-b border-base-300 pb-5 lg:flex-row lg:items-end lg:justify-between">
          <div class="min-w-0">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
              Project registry
            </p>
            <h1 class="mt-2 text-3xl font-semibold tracking-normal text-base-content">
              Projects
            </h1>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-base-content/60">
              Jump into triage, review intake limits, or open project settings for a service.
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-3 lg:justify-end">
            <div
              id="project-count-summary"
              class="rounded-lg border border-base-300 bg-base-100 px-4 py-2 text-sm text-base-content/55 shadow-sm"
            >
              <span class="font-semibold text-base-content">{@project_count}</span>
              {if @project_count == 1, do: "project", else: "projects"}
            </div>
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
          <div class="grid gap-3 border-b border-base-300 bg-base-200/40 px-5 py-4 md:grid-cols-[minmax(0,1fr)_14rem_18rem]">
            <h2 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/45">
              Service
            </h2>
            <p class="hidden text-xs font-semibold uppercase tracking-[0.14em] text-base-content/45 md:block">
              Ingest policy
            </p>
            <p class="hidden text-right text-xs font-semibold uppercase tracking-[0.14em] text-base-content/45 md:block">
              Actions
            </p>
          </div>

          <div id="projects" phx-update="stream" class="divide-y divide-base-300">
            <div id="projects-empty-state" class="hidden px-5 py-12 text-center only:block">
              <div class="mx-auto flex max-w-sm flex-col items-center gap-4">
                <div class="rounded-full bg-primary/10 p-3 text-primary">
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
              class="grid gap-4 px-5 py-4 transition hover:bg-base-200/55 md:grid-cols-[minmax(0,1fr)_14rem] xl:grid-cols-[minmax(0,1fr)_14rem_18rem] xl:items-center"
            >
              <div class="flex min-w-0 items-center gap-4">
                <div
                  id={"project-platform-logo-#{project.id}"}
                  class={[
                    "flex size-12 shrink-0 items-center justify-center rounded-lg text-base font-black tracking-normal shadow-sm ring-1 ring-black/5",
                    platform_tone_class(project.platform)
                  ]}
                >
                  {platform_mark(project.platform)}
                </div>

                <div class="min-w-0">
                  <.link
                    id={"project-open-link-#{project.id}"}
                    navigate={~p"/issues?project=#{project.id}"}
                    class="group inline-flex max-w-full items-center gap-2"
                  >
                    <span class="truncate text-lg font-semibold text-base-content group-hover:text-primary">
                      {project.name}
                    </span>
                    <.icon
                      name="hero-arrow-right"
                      class="size-4 shrink-0 text-base-content/35 group-hover:text-primary"
                    />
                  </.link>

                  <div class="mt-2 flex flex-wrap items-center gap-2 text-sm text-base-content/55">
                    <span
                      id={"project-platform-#{project.id}"}
                      class="rounded bg-base-200 px-2 py-1 font-medium text-base-content/70"
                    >
                      {Projects.project_platform_label(project.platform)}
                    </span>
                    <span class="font-mono text-xs text-base-content/40">{project.slug}</span>
                  </div>
                </div>
              </div>

              <div
                id={"project-ingest-policy-#{project.id}"}
                class="grid grid-cols-2 gap-2 rounded-lg border border-base-300 bg-base-200/45 px-3 py-2 text-sm md:grid-cols-1"
              >
                <div>
                  <p class="text-xs font-semibold uppercase tracking-[0.12em] text-base-content/40">
                    Limit
                  </p>
                  <p class="mt-0.5 font-semibold text-base-content">
                    {project.rate_limit_max_events}
                    <span class="font-normal text-base-content/45">
                      / {project.rate_limit_window_seconds}s
                    </span>
                  </p>
                </div>
                <div class="md:hidden">
                  <p class="text-xs font-semibold uppercase tracking-[0.12em] text-base-content/40">
                    Platform
                  </p>
                  <p class="mt-0.5 font-semibold text-base-content">
                    {Projects.project_platform_label(project.platform)}
                  </p>
                </div>
              </div>

              <div class="grid gap-2 sm:grid-cols-2 md:col-span-2 xl:col-span-1 xl:flex xl:justify-end">
                <.link
                  id={"project-issues-link-#{project.id}"}
                  navigate={~p"/issues?project=#{project.id}"}
                  class="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md xl:shrink-0"
                >
                  Open triage <.icon name="hero-arrow-right" class="size-4" />
                </.link>
                <.link
                  id={"project-settings-link-#{project.id}"}
                  navigate={~p"/p/#{project.slug}/settings"}
                  class="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg border border-base-300 px-3 py-2.5 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content xl:shrink-0"
                >
                  <.icon name="hero-cog-6-tooth" class="size-4" />
                  <span class="sm:sr-only xl:not-sr-only">Settings</span>
                </.link>
              </div>
            </article>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp platform_mark("other"), do: "?"
  defp platform_mark("nextjs"), do: "N"
  defp platform_mark("react"), do: "R"
  defp platform_mark("react_native"), do: "RN"
  defp platform_mark("nodejs"), do: "N"
  defp platform_mark("laravel"), do: "L"
  defp platform_mark("fastapi"), do: "F"
  defp platform_mark("flutter"), do: "F"
  defp platform_mark("django"), do: "dj"
  defp platform_mark("python"), do: "Py"
  defp platform_mark("express"), do: "ex"
  defp platform_mark("browser_javascript"), do: "JS"
  defp platform_mark("php"), do: "php"
  defp platform_mark("rails"), do: "R"
  defp platform_mark("ios"), do: "iOS"
  defp platform_mark("nestjs"), do: "N"
  defp platform_mark("flask"), do: "F"
  defp platform_mark("vue"), do: "V"
  defp platform_mark("aspnet_core"), do: ".NET"
  defp platform_mark("nuxt"), do: "Nu"
  defp platform_mark("dotnet_maui"), do: ".NET"
  defp platform_mark("angular"), do: "A"
  defp platform_mark("android"), do: "A"
  defp platform_mark("spring_boot"), do: "S"
  defp platform_mark("symfony"), do: "sf"
  defp platform_mark("cloudflare_workers"), do: "W"
  defp platform_mark("electron"), do: "E"
  defp platform_mark("unity"), do: "U"
  defp platform_mark("remix"), do: "R"
  defp platform_mark(_platform), do: "?"

  defp platform_tone_class("other"), do: "bg-base-content text-base-100"
  defp platform_tone_class("nextjs"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("react"), do: "bg-cyan-950 text-cyan-200"
  defp platform_tone_class("react_native"), do: "bg-sky-600 text-white"
  defp platform_tone_class("nodejs"), do: "bg-zinc-800 text-lime-400"
  defp platform_tone_class("laravel"), do: "bg-red-600 text-white"
  defp platform_tone_class("fastapi"), do: "bg-emerald-600 text-white"
  defp platform_tone_class("flutter"), do: "bg-sky-500 text-white"
  defp platform_tone_class("django"), do: "bg-emerald-950 text-white"
  defp platform_tone_class("python"), do: "bg-blue-700 text-yellow-300"
  defp platform_tone_class("express"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("browser_javascript"), do: "bg-yellow-300 text-zinc-950"
  defp platform_tone_class("php"), do: "bg-indigo-600 text-white"
  defp platform_tone_class("rails"), do: "bg-red-700 text-white"
  defp platform_tone_class("ios"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("nestjs"), do: "bg-rose-600 text-white"
  defp platform_tone_class("flask"), do: "bg-cyan-700 text-white"
  defp platform_tone_class("vue"), do: "bg-emerald-500 text-white"
  defp platform_tone_class("aspnet_core"), do: "bg-violet-600 text-white"
  defp platform_tone_class("nuxt"), do: "bg-zinc-950 text-emerald-300"
  defp platform_tone_class("dotnet_maui"), do: "bg-violet-600 text-white"
  defp platform_tone_class("angular"), do: "bg-fuchsia-600 text-white"
  defp platform_tone_class("android"), do: "bg-green-600 text-white"
  defp platform_tone_class("spring_boot"), do: "bg-green-700 text-white"
  defp platform_tone_class("symfony"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("cloudflare_workers"), do: "bg-orange-500 text-white"
  defp platform_tone_class("electron"), do: "bg-slate-800 text-cyan-200"
  defp platform_tone_class("unity"), do: "bg-zinc-950 text-white"
  defp platform_tone_class("remix"), do: "bg-zinc-900 text-white"
  defp platform_tone_class(_platform), do: "bg-base-300 text-base-content"
end
