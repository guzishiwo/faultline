defmodule FaultlineWeb.IssueLive.Index do
  use FaultlineWeb, :live_view

  alias Faultline.Issues
  alias Faultline.Projects

  @page_size 20

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    project = Projects.get_project!(project_id)
    page = Issues.paginate_project_issues(project.id, limit: @page_size)

    if connected?(socket), do: Issues.subscribe(project.id)

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:next_cursor, page.next_cursor)
     |> stream(:issues, page.issues, reset: true)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    page =
      Issues.paginate_project_issues(socket.assigns.project.id,
        limit: @page_size,
        after: socket.assigns.next_cursor
      )

    socket =
      Enum.reduce(page.issues, socket, fn issue, socket ->
        stream_insert(socket, :issues, issue)
      end)

    {:noreply, assign(socket, :next_cursor, page.next_cursor)}
  end

  @impl true
  def handle_info({:issue_changed, issue}, socket) do
    if issue.project_id == socket.assigns.project.id do
      {:noreply, stream_insert(socket, :issues, issue, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto w-full max-w-7xl space-y-6">
        <header class="flex flex-col gap-4 border-b border-base-300 pb-5 lg:flex-row lg:items-end lg:justify-between">
          <div class="space-y-2">
            <.link
              id="back-to-projects-link"
              navigate={~p"/projects"}
              class="inline-flex items-center gap-2 text-sm font-semibold text-base-content/60 transition hover:text-base-content"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Projects
            </.link>
            <div>
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-orange-600">
                {@project.name}
              </p>
              <h1 class="mt-2 text-3xl font-semibold tracking-normal text-base-content">
                Issues
              </h1>
            </div>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100 px-4 py-3 text-sm text-base-content/70 shadow-sm">
            <span class="font-semibold text-base-content">DSN</span>
            <code class="ml-2 font-mono text-xs">{@project.dsn}</code>
          </div>
        </header>

        <section class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm">
          <div class="grid grid-cols-[1fr_7rem_7rem_7rem_10rem] gap-4 border-b border-base-300 px-5 py-3 text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
            <span>Issue</span>
            <span>Status</span>
            <span>Events</span>
            <span>Users</span>
            <span>Last seen</span>
          </div>

          <div id="issues" phx-update="stream" class="divide-y divide-base-300">
            <div id="issues-empty-state" class="hidden px-5 py-12 text-center only:block">
              <p class="font-semibold text-base-content">No issues yet</p>
              <p class="mt-1 text-sm text-base-content/60">Ingested errors will appear here.</p>
            </div>

            <.link
              :for={{id, issue} <- @streams.issues}
              id={id}
              navigate={~p"/projects/#{@project.id}/issues/#{issue.id}"}
              class="grid grid-cols-[1fr_7rem_7rem_7rem_10rem] gap-4 px-5 py-4 transition hover:bg-base-200/70"
            >
              <div class="min-w-0">
                <p class="truncate font-semibold text-base-content">{issue.title}</p>
                <p class="mt-1 truncate font-mono text-xs text-base-content/45">
                  {issue.fingerprint}
                </p>
              </div>
              <span class={status_class(issue.status)}>{issue.status}</span>
              <span class="text-sm font-semibold text-base-content">{issue.event_count}</span>
              <span class="text-sm font-semibold text-base-content">{issue.affected_user_count}</span>
              <time class="text-sm text-base-content/65">{format_time(issue.last_seen_at)}</time>
            </.link>
          </div>
        </section>

        <div :if={@next_cursor} class="flex justify-center">
          <button
            id="load-more-issues"
            type="button"
            phx-click="load_more"
            class="inline-flex items-center gap-2 rounded-lg border border-base-300 bg-base-100 px-4 py-2 text-sm font-semibold text-base-content shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <.icon name="hero-arrow-down" class="size-4" /> Load more
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_class("unresolved"),
    do:
      "inline-flex w-fit rounded-md bg-red-50 px-2 py-1 text-xs font-semibold uppercase tracking-[0.12em] text-red-700"

  defp status_class("resolved"),
    do:
      "inline-flex w-fit rounded-md bg-emerald-50 px-2 py-1 text-xs font-semibold uppercase tracking-[0.12em] text-emerald-700"

  defp status_class("ignored"),
    do:
      "inline-flex w-fit rounded-md bg-zinc-100 px-2 py-1 text-xs font-semibold uppercase tracking-[0.12em] text-zinc-700"

  defp format_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
end
