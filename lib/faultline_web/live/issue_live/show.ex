defmodule FaultlineWeb.IssueLive.Show do
  use FaultlineWeb, :live_view

  alias Faultline.Events
  alias Faultline.Issues
  alias Faultline.Projects

  @impl true
  def mount(%{"project_id" => project_id, "id" => issue_id}, _session, socket) do
    project = Projects.get_project!(project_id)
    issue = Issues.get_project_issue!(project.id, issue_id)
    events = Events.list_issue_events(issue.id, limit: 20)

    if connected?(socket), do: Issues.subscribe(project.id)

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:issue, issue)
     |> assign(:events, events)
     |> assign(:raw_event_json, nil)
     |> assign(:selected_event_id, nil)}
  end

  @impl true
  def handle_event("set_status", %{"status" => status}, socket) do
    case Issues.update_issue_status(socket.assigns.issue, status) do
      {:ok, issue} ->
        {:noreply, assign(socket, :issue, issue)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update issue status.")}
    end
  end

  def handle_event("load_raw", %{"id" => event_id}, socket) do
    event = Events.get_issue_event_with_raw!(socket.assigns.issue.id, event_id)

    raw_event_json =
      event.raw_event.payload
      |> Jason.encode!(pretty: true)

    {:noreply,
     socket
     |> assign(:raw_event_json, raw_event_json)
     |> assign(:selected_event_id, event.id)}
  end

  @impl true
  def handle_info({:issue_changed, issue}, socket) do
    if issue.id == socket.assigns.issue.id do
      {:noreply, assign(socket, :issue, issue)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-7xl space-y-6">
        <header class="flex flex-col gap-5 border-b border-base-300 pb-5 lg:flex-row lg:items-start lg:justify-between">
          <div class="min-w-0 space-y-3">
            <.link
              id="back-to-issues-link"
              navigate={~p"/projects/#{@project.id}/issues"}
              class="inline-flex items-center gap-2 text-sm font-semibold text-base-content/60 transition hover:text-base-content"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Issues
            </.link>
            <div>
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-orange-600">
                {@project.name}
              </p>
              <h1 class="mt-2 max-w-4xl text-3xl font-semibold tracking-normal text-base-content">
                {@issue.title}
              </h1>
            </div>
          </div>

          <div id="issue-status-controls" class="flex flex-wrap gap-2">
            <button
              :for={status <- ~w(unresolved resolved ignored)}
              id={"set-status-#{status}"}
              type="button"
              phx-click="set_status"
              phx-value-status={status}
              class={[
                "rounded-lg border px-3 py-2 text-sm font-semibold transition hover:-translate-y-0.5",
                @issue.status == status &&
                  "border-base-content bg-base-content text-base-100 shadow-sm",
                @issue.status != status &&
                  "border-base-300 bg-base-100 text-base-content/70 hover:text-base-content"
              ]}
            >
              {status}
            </button>
          </div>
        </header>

        <section class="grid gap-4 md:grid-cols-4">
          <div class="rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
              Status
            </p>
            <p id="issue-status" class="mt-2 text-lg font-semibold text-base-content">
              {@issue.status}
            </p>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
              Events
            </p>
            <p class="mt-2 text-lg font-semibold text-base-content">{@issue.event_count}</p>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
              Users
            </p>
            <p class="mt-2 text-lg font-semibold text-base-content">{@issue.affected_user_count}</p>
          </div>
          <div class="rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
              Last seen
            </p>
            <p class="mt-2 text-sm font-semibold text-base-content">
              {format_time(@issue.last_seen_at)}
            </p>
          </div>
        </section>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_26rem]">
          <div id="issue-events" class="space-y-4">
            <article
              :for={event <- @events}
              id={"issue-event-#{event.id}"}
              class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
            >
              <div class="flex flex-col gap-3 border-b border-base-300 pb-4 lg:flex-row lg:items-start lg:justify-between">
                <div class="min-w-0">
                  <p class="font-mono text-xs text-base-content/50">{event.event_id}</p>
                  <h2 class="mt-1 truncate text-lg font-semibold text-base-content">
                    {event.message || event.exception_value || "Event"}
                  </h2>
                  <p class="mt-1 text-sm text-base-content/60">
                    {event.platform || "unknown"} &middot; {event.level || "unknown"} &middot; {format_time(
                      event.occurred_at
                    )}
                  </p>
                </div>
                <button
                  id={"load-raw-event-#{event.id}"}
                  type="button"
                  phx-click="load_raw"
                  phx-value-id={event.id}
                  class="inline-flex w-fit items-center gap-2 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:-translate-y-0.5 hover:text-base-content"
                >
                  <.icon name="hero-code-bracket" class="size-4" /> Raw JSON
                </button>
              </div>

              <div class="mt-4 grid gap-4 lg:grid-cols-2">
                <dl class="grid gap-2 text-sm">
                  <.kv label="Exception" value={compact_exception(event)} />
                  <.kv label="Culprit" value={event.culprit} />
                  <.kv label="Release" value={event.release} />
                  <.kv label="Environment" value={event.environment} />
                  <.kv label="Server" value={event.server_name} />
                  <.kv label="User" value={event.user_identifier} />
                  <.kv label="Request" value={event.request_url} />
                </dl>

                <div class="space-y-4">
                  <.map_section title="Tags" values={event.details["tags"] || %{}} />
                  <.stacktrace frames={
                    get_in(event.details, ["exception", "stacktrace_frames"]) || []
                  } />
                  <.breadcrumbs values={event.details["breadcrumbs"] || []} />
                </div>
              </div>
            </article>
          </div>

          <aside
            id="raw-event-panel"
            class="h-fit rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm"
          >
            <div class="flex items-center justify-between gap-3">
              <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/50">
                Raw event
              </h2>
              <span :if={@selected_event_id} class="font-mono text-xs text-base-content/45">
                #{@selected_event_id}
              </span>
            </div>
            <pre
              :if={@raw_event_json}
              id="raw-event-json"
              phx-no-curly-interpolation
              class="mt-3 max-h-[36rem] overflow-auto rounded-md bg-base-200 p-3 text-xs leading-5 text-base-content"
            ><%= @raw_event_json %></pre>
            <p :if={!@raw_event_json} class="mt-3 text-sm leading-6 text-base-content/60">
              Select an event to load its raw SDK payload.
            </p>
          </aside>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, default: nil

  defp kv(assigns) do
    ~H"""
    <div class="grid grid-cols-[7rem_minmax(0,1fr)] gap-3">
      <dt class="text-base-content/50">{@label}</dt>
      <dd class="min-w-0 truncate font-medium text-base-content">{@value || "-"}</dd>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :values, :map, required: true

  defp map_section(assigns) do
    ~H"""
    <section>
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        {@title}
      </h3>
      <div class="mt-2 grid gap-1 text-sm">
        <p :if={map_size(@values) == 0} class="text-base-content/50">None</p>
        <div :for={{key, value} <- @values} class="grid grid-cols-[7rem_minmax(0,1fr)] gap-2">
          <span class="truncate text-base-content/50">{key}</span>
          <span class="truncate font-medium text-base-content">{inspect(value)}</span>
        </div>
      </div>
    </section>
    """
  end

  attr :frames, :list, required: true

  defp stacktrace(assigns) do
    ~H"""
    <section>
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        Stacktrace
      </h3>
      <div class="mt-2 space-y-1">
        <p :if={@frames == []} class="text-sm text-base-content/50">No frames</p>
        <div
          :for={frame <- @frames}
          class="rounded-md bg-base-200 px-3 py-2 font-mono text-xs text-base-content"
        >
          <p class="truncate">{frame["function"] || frame["module"] || "anonymous"}</p>
          <p class="truncate text-base-content/50">
            {frame["filename"] || frame["abs_path"] || "unknown"}:{frame["lineno"] || "?"}
          </p>
        </div>
      </div>
    </section>
    """
  end

  attr :values, :list, required: true

  defp breadcrumbs(assigns) do
    ~H"""
    <section>
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        Breadcrumbs
      </h3>
      <div class="mt-2 space-y-1">
        <p :if={@values == []} class="text-sm text-base-content/50">No breadcrumbs</p>
        <div :for={breadcrumb <- @values} class="rounded-md bg-base-200 px-3 py-2 text-xs">
          <p class="font-semibold text-base-content">{breadcrumb["category"] || "breadcrumb"}</p>
          <p class="text-base-content/60">{breadcrumb["message"] || inspect(breadcrumb)}</p>
        </div>
      </div>
    </section>
    """
  end

  defp compact_exception(event) do
    [event.exception_type, event.exception_value]
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(": ")
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp format_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
end
