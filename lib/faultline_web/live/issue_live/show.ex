defmodule FaultlineWeb.IssueLive.Show do
  use FaultlineWeb, :live_view

  alias Faultline.Events
  alias Faultline.Issues
  alias FaultlineWeb.IssueLive.{EventDetail, ShowComponents}
  alias FaultlineWeb.TimeComponents
  alias Faultline.Projects

  @impl true
  def mount(%{"id" => issue_id} = params, _session, socket) do
    project = Projects.get_project_by_route_param!(params)
    issue = Issues.get_project_issue!(project.id, issue_id)
    events = Events.list_issue_events(issue.id, limit: 20)

    if connected?(socket), do: Issues.subscribe(project.id)

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:issue, issue)
     |> assign(:events, events)
     |> assign(:event_search_query, "")
     |> assign(:event_filter_form, event_filter_form(""))
     |> assign(:selected_event, selected_event_for_detail(issue.id, List.first(events)))
     |> assign(:raw_event_payload, nil)
     |> assign(:raw_event_event_id, nil)}
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

    {:noreply,
     socket
     |> assign(:selected_event, with_raw_detail_fallbacks(event))
     |> assign(:raw_event_payload, event.raw_event.payload)
     |> assign(:raw_event_event_id, event.id)}
  end

  def handle_event("select_event", %{"id" => event_id}, socket) do
    case find_event(socket.assigns.events, event_id) do
      nil ->
        {:noreply, socket}

      event ->
        {:noreply,
         socket
         |> assign(:selected_event, selected_event_for_detail(socket.assigns.issue.id, event))
         |> assign(:raw_event_payload, nil)
         |> assign(:raw_event_event_id, nil)}
    end
  end

  def handle_event("filter_events", %{"event_filters" => %{"q" => query}}, socket) do
    query = normalize_event_search(query)
    events = Events.list_issue_events(socket.assigns.issue.id, limit: 20, search: query)

    {:noreply,
     socket
     |> assign(:events, events)
     |> assign(:event_search_query, query)
     |> assign(:event_filter_form, event_filter_form(query))
     |> assign(
       :selected_event,
       selected_event_for_detail(socket.assigns.issue.id, List.first(events))
     )
     |> assign(:raw_event_payload, nil)
     |> assign(:raw_event_event_id, nil)}
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
              navigate={~p"/issues?project=#{@project.id}"}
              class="inline-flex items-center gap-2 text-sm font-semibold text-base-content/60 transition hover:text-base-content"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Issues
            </.link>
            <div>
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
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
              class={status_button_class(status, @issue.status)}
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
            <TimeComponents.local_time
              id="issue-last-seen"
              datetime={@issue.last_seen_at}
              class="mt-2 block text-sm font-semibold text-base-content"
            />
          </div>
        </section>

        <section class="grid gap-6 xl:grid-cols-[19rem_minmax(0,1fr)]">
          <aside
            id="issue-occurrences"
            class="h-fit overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm"
          >
            <div class="border-b border-base-300 px-4 py-3">
              <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/50">
                Occurrences
              </h2>
              <p class="mt-1 text-xs text-base-content/50">
                Latest {@events |> length()} shown
              </p>
            </div>

            <.form
              for={@event_filter_form}
              id="issue-event-search-form"
              phx-change="filter_events"
              phx-submit="filter_events"
              class="border-b border-base-300 p-3"
            >
              <div class="relative [&_.fieldset]:mb-0">
                <.icon
                  name="hero-magnifying-glass"
                  class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-base-content/35"
                />
                <.input
                  field={@event_filter_form[:q]}
                  type="search"
                  placeholder="release: web@2.0.0"
                  autocomplete="off"
                  phx-debounce="300"
                  aria-label="Filter issue events"
                  class="h-10 w-full rounded-lg border border-base-300 bg-base-100 pl-9 pr-3 text-sm text-base-content shadow-sm outline-none transition placeholder:text-base-content/35 focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
              </div>
            </.form>

            <div class="max-h-[42rem] overflow-auto">
              <p :if={@events == []} class="p-4 text-sm text-base-content/60">
                No events yet.
              </p>
              <button
                :for={event <- @events}
                id={"select-event-#{event.id}"}
                type="button"
                phx-click="select_event"
                phx-value-id={event.id}
                class={[
                  "block w-full border-b border-base-300 px-4 py-3 text-left transition last:border-b-0 hover:bg-base-200",
                  selected_event?(@selected_event, event) && "bg-base-200",
                  !selected_event?(@selected_event, event) && "bg-base-100"
                ]}
              >
                <span class="block truncate font-mono text-[0.7rem] text-base-content/45">
                  {event.event_id}
                </span>
                <span class="mt-1 block text-sm font-semibold leading-5 text-base-content">
                  {EventDetail.occurrence_title(event)}
                </span>
                <span class="mt-1 block text-xs text-base-content/55">
                  {event.release || "unknown release"}
                </span>
                <span class="mt-1 flex items-center justify-between gap-2 text-xs text-base-content/55">
                  <span>{event.environment || "unknown env"}</span>
                  <TimeComponents.local_time
                    id={"occurrence-#{event.id}-occurred-at"}
                    datetime={event.occurred_at}
                  />
                </span>
              </button>
            </div>
          </aside>

          <div id="selected-event-detail" class="space-y-4">
            <article
              :if={@selected_event}
              id={"issue-event-#{@selected_event.id}"}
              class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm"
            >
              <div class="flex flex-col gap-3 border-b border-base-300 p-5 lg:flex-row lg:items-start lg:justify-between">
                <div class="min-w-0">
                  <p class="font-mono text-xs text-base-content/50">{@selected_event.event_id}</p>
                  <h2 class="mt-1 text-lg font-semibold leading-7 text-base-content">
                    {@selected_event.message || @selected_event.exception_value || "Event"}
                  </h2>
                  <p class="mt-1 text-sm text-base-content/60">
                    {@selected_event.platform || "unknown"} &middot; {@selected_event.level ||
                      "unknown"} &middot;
                    <TimeComponents.local_time
                      id="selected-event-occurred-at"
                      datetime={@selected_event.occurred_at}
                      class="inline"
                    />
                  </p>
                </div>
                <button
                  id={"load-raw-event-#{@selected_event.id}"}
                  type="button"
                  phx-click="load_raw"
                  phx-value-id={@selected_event.id}
                  class="inline-flex w-fit shrink-0 items-center gap-2 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:-translate-y-0.5 hover:border-base-content/30 hover:bg-base-200 hover:text-base-content"
                >
                  <.icon name="hero-code-bracket" class="size-4" /> Raw JSON
                </button>
              </div>

              <div class="space-y-5 p-5">
                <ShowComponents.collapsible_section
                  id="event-overview"
                  title="Overview"
                  border={false}
                >
                  <dl class="grid gap-x-5 gap-y-3 text-sm sm:grid-cols-2 xl:grid-cols-3">
                    <ShowComponents.kv
                      label="Exception"
                      value={EventDetail.compact_exception(@selected_event)}
                    />
                    <ShowComponents.kv
                      label="Mechanism"
                      value={EventDetail.mechanism_summary(@selected_event)}
                    />
                    <ShowComponents.kv label="Culprit" value={@selected_event.culprit} />
                    <ShowComponents.kv label="Release" value={@selected_event.release} />
                    <ShowComponents.kv label="Environment" value={@selected_event.environment} />
                    <ShowComponents.kv label="Server" value={@selected_event.server_name} />
                    <ShowComponents.kv label="User" value={@selected_event.user_identifier} />
                    <ShowComponents.kv label="Request" value={@selected_event.request_url} />
                    <ShowComponents.kv
                      label="Trace"
                      value={EventDetail.trace_summary(@selected_event)}
                    />
                  </dl>
                </ShowComponents.collapsible_section>

                <ShowComponents.collapsible_section id="event-stacktrace" title="Stacktrace">
                  <ShowComponents.stacktrace
                    frames={get_in(@selected_event.details, ["exception", "stacktrace_frames"]) || []}
                    event_id={@selected_event.id}
                  />
                </ShowComponents.collapsible_section>

                <ShowComponents.collapsible_section id="event-context" title="Context">
                  <div class="grid gap-5 lg:grid-cols-2">
                    <ShowComponents.map_section
                      title="Tags"
                      values={@selected_event.details["tags"] || %{}}
                    />
                    <ShowComponents.map_section
                      title="User"
                      values={@selected_event.details["user"] || %{}}
                    />
                    <ShowComponents.map_section
                      title="Request"
                      values={@selected_event.details["request"] || %{}}
                    />
                    <ShowComponents.context_cards contexts={
                      @selected_event.details["contexts"] || %{}
                    } />
                  </div>
                </ShowComponents.collapsible_section>

                <ShowComponents.collapsible_section id="event-sdk" title="SDK and runtime">
                  <div class="grid gap-5 lg:grid-cols-2">
                    <ShowComponents.map_section
                      title="SDK"
                      values={EventDetail.sdk_summary(@selected_event)}
                    />
                    <ShowComponents.modules values={@selected_event.details["modules"] || %{}} />
                  </div>
                </ShowComponents.collapsible_section>

                <ShowComponents.collapsible_section
                  id="event-breadcrumbs"
                  title="Breadcrumbs"
                  open={(@selected_event.details["breadcrumbs"] || []) != []}
                >
                  <ShowComponents.breadcrumbs values={@selected_event.details["breadcrumbs"] || []} />
                </ShowComponents.collapsible_section>
              </div>
            </article>

            <aside
              id="raw-event-panel"
              class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm"
            >
              <div class="flex items-center justify-between gap-3 border-b border-base-300 px-4 py-3">
                <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/50">
                  Raw event
                </h2>
                <span :if={@raw_event_event_id} class="font-mono text-xs text-base-content/45">
                  #{@raw_event_event_id}
                </span>
              </div>
              <pre
                :if={@raw_event_payload}
                id="raw-event-json"
                class="max-h-[34rem] overflow-auto bg-base-200 p-4 text-xs leading-5 stacktrace-list"
              ><code
                  id={"raw-event-json-code-#{@raw_event_event_id}"}
                  phx-hook="CodeHighlight"
                  phx-update="ignore"
                  data-prism-language="json"
                  class="block min-w-full whitespace-pre-wrap break-words language-json"
                >{EventDetail.raw_event_json(@raw_event_payload)}</code></pre>
              <p :if={!@raw_event_payload} class="p-4 text-sm leading-6 text-base-content/60">
                Load raw JSON for the selected occurrence.
              </p>
            </aside>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp find_event(events, event_id) do
    with {:ok, id} <- Ecto.UUID.cast(event_id) do
      Enum.find(events, &(&1.id == id))
    else
      _ -> nil
    end
  end

  defp event_filter_form(search_query) do
    to_form(%{"q" => search_query}, as: :event_filters)
  end

  defp normalize_event_search(search_query) when is_binary(search_query),
    do: String.trim(search_query)

  defp normalize_event_search(_search_query), do: ""

  defp selected_event?(%{id: selected_id}, %{id: event_id}), do: selected_id == event_id
  defp selected_event?(_selected_event, _event), do: false

  defp selected_event_for_detail(_issue_id, nil), do: nil

  defp selected_event_for_detail(issue_id, event) do
    issue_id
    |> Events.get_issue_event_with_raw!(event.id)
    |> with_raw_detail_fallbacks()
  end

  defp with_raw_detail_fallbacks(event) do
    raw_payload = loaded_raw_payload(event)

    details =
      (event.details || %{})
      |> fill_raw_map_detail(raw_payload, "contexts")
      |> fill_raw_map_detail(raw_payload, "modules")
      |> fill_raw_map_detail(raw_payload, "sdk")

    %{event | details: details}
  end

  defp loaded_raw_payload(%{raw_event: raw_event}) do
    if Ecto.assoc_loaded?(raw_event), do: raw_event.payload || %{}, else: %{}
  end

  defp loaded_raw_payload(_event), do: %{}

  defp fill_raw_map_detail(details, raw_payload, key) do
    current_value = Map.get(details, key)
    raw_value = Map.get(raw_payload, key)

    if blank_detail?(current_value) and is_map(raw_value) do
      Map.put(details, key, raw_value)
    else
      details
    end
  end

  defp status_button_class(status, current_status) do
    [
      "rounded-lg border px-3 py-2 text-sm font-semibold transition hover:-translate-y-0.5",
      status_selected_class(status, status == current_status)
    ]
  end

  defp status_selected_class("unresolved", true),
    do: "border-error/40 bg-error/10 text-error shadow-sm ring-1 ring-error/10"

  defp status_selected_class("unresolved", false),
    do:
      "border-error/25 bg-base-100 text-error/80 hover:border-error/40 hover:bg-error/5 hover:text-error"

  defp status_selected_class("resolved", true),
    do: "border-success/40 bg-success/10 text-success shadow-sm ring-1 ring-success/10"

  defp status_selected_class("resolved", false),
    do:
      "border-success/25 bg-base-100 text-success/80 hover:border-success/40 hover:bg-success/5 hover:text-success"

  defp status_selected_class("ignored", true),
    do:
      "border-base-content/25 bg-base-200 text-base-content shadow-sm ring-1 ring-base-content/5"

  defp status_selected_class("ignored", false),
    do:
      "border-base-300 bg-base-100 text-base-content/60 hover:border-base-content/30 hover:bg-base-200 hover:text-base-content"

  defp blank_detail?(nil), do: true
  defp blank_detail?(""), do: true
  defp blank_detail?(value) when is_map(value), do: map_size(value) == 0
  defp blank_detail?(value) when is_list(value), do: value == []
  defp blank_detail?(_value), do: false
end
