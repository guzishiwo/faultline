defmodule FaultlineWeb.ProjectLive.Usage do
  use FaultlineWeb, :live_view

  alias Faultline.Projects

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    usage = Projects.get_project_usage!(project_id)

    {:ok, assign(socket, :usage, usage)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="project-usage-page" class="mx-auto w-full max-w-6xl space-y-6">
        <header class="flex flex-col gap-4 border-b border-base-300 pb-5 lg:flex-row lg:items-start lg:justify-between">
          <div class="space-y-3">
            <.link
              id="back-to-project-settings-link"
              navigate={~p"/projects/#{@usage.project.id}/settings"}
              class="inline-flex items-center gap-2 text-sm font-semibold text-base-content/60 transition hover:text-base-content"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Project settings
            </.link>
            <div>
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-orange-600">
                {@usage.project.name}
              </p>
              <h1 class="mt-2 text-3xl font-semibold tracking-normal text-base-content">
                Usage
              </h1>
            </div>
          </div>

          <.link
            id="project-issues-link"
            navigate={~p"/projects/#{@usage.project.id}/issues"}
            class="inline-flex w-fit items-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            Open triage <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </header>

        <section class="grid gap-4 sm:grid-cols-3">
          <.usage_stat id="usage-events" label="Events" value={@usage.event_count} />
          <.usage_stat id="usage-raw-events" label="Raw events" value={@usage.raw_event_count} />
          <.usage_stat id="usage-issues" label="Issues" value={@usage.issue_count} />
        </section>

        <section
          id="usage-retention"
          class="grid gap-4 rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm sm:grid-cols-2"
        >
          <div>
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Retention window
            </h2>
            <p class="mt-2 text-2xl font-semibold text-base-content">
              {@usage.project.retention_days} days
            </p>
          </div>
          <div>
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Event cap
            </h2>
            <p class="mt-2 text-2xl font-semibold text-base-content">
              {@usage.project.retention_event_limit}
            </p>
          </div>
          <div>
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Earliest event
            </h2>
            <p class="mt-2 text-sm font-medium text-base-content/70">
              {format_usage_time(@usage.earliest_event_at)}
            </p>
          </div>
          <div>
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Latest event
            </h2>
            <p class="mt-2 text-sm font-medium text-base-content/70">
              {format_usage_time(@usage.latest_event_at)}
            </p>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp usage_stat(assigns) do
    ~H"""
    <section id={@id} class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm">
      <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
        {@label}
      </h2>
      <p class="mt-2 text-3xl font-semibold text-base-content">{@value}</p>
    </section>
    """
  end

  defp format_usage_time(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

  defp format_usage_time(_datetime), do: "-"
end
