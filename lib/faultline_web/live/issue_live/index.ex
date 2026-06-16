defmodule FaultlineWeb.IssueLive.Index do
  use FaultlineWeb, :live_view

  alias Faultline.Issues
  alias Faultline.Projects

  @page_size 20
  @all_projects "-1"
  @all_statuses "all"
  @all_time "all"
  @status_options [
    {"All statuses", @all_statuses},
    {"Unresolved", "unresolved"},
    {"Resolved", "resolved"},
    {"Ignored", "ignored"}
  ]
  @time_options [
    {"Any time", @all_time},
    {"Last 24 hours", "24h"},
    {"Last 7 days", "7d"},
    {"Last 30 days", "30d"}
  ]

  @impl true
  def mount(params, _session, socket) do
    projects = Projects.list_projects()

    if connected?(socket), do: Issues.subscribe_all()

    {:ok,
     socket
     |> assign(:projects, projects)
     |> assign(:all_projects, @all_projects)
     |> assign(:status_options, @status_options)
     |> assign(:time_options, @time_options)
     |> apply_filters(params)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_filters(socket, params)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filter_params}, socket) do
    {:noreply, push_patch(socket, to: issues_index_path(filter_params))}
  end

  def handle_event("select_project", %{"project" => project_filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         issues_index_path(%{
           "q" => socket.assigns.search_query,
           "project" => project_filter,
           "status" => socket.assigns.status_filter,
           "time" => socket.assigns.time_filter
         })
     )}
  end

  def handle_event("select_status", %{"status" => status_filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         issues_index_path(%{
           "q" => socket.assigns.search_query,
           "project" => socket.assigns.project_filter,
           "status" => status_filter,
           "time" => socket.assigns.time_filter
         })
     )}
  end

  def handle_event("select_time", %{"time" => time_filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         issues_index_path(%{
           "q" => socket.assigns.search_query,
           "project" => socket.assigns.project_filter,
           "status" => socket.assigns.status_filter,
           "time" => time_filter
         })
     )}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         issues_index_path(%{
           "q" => "",
           "project" => socket.assigns.project_filter,
           "status" => socket.assigns.status_filter,
           "time" => socket.assigns.time_filter
         })
     )}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         issues_index_path(%{
           "q" => "",
           "project" => @all_projects,
           "status" => @all_statuses,
           "time" => @all_time
         })
     )}
  end

  def handle_event("load_more", _params, socket) do
    page =
      Issues.paginate_issues(
        limit: @page_size,
        after: socket.assigns.next_cursor,
        project_id: socket.assigns.selected_project_id,
        search: socket.assigns.search_query,
        status: socket.assigns.selected_status,
        last_seen_since: socket.assigns.last_seen_since
      )

    socket =
      Enum.reduce(page.issues, socket, fn issue, socket ->
        stream_insert(socket, :issues, issue)
      end)

    {:noreply, assign(socket, :next_cursor, page.next_cursor)}
  end

  @impl true
  def handle_info({:issue_changed, issue}, socket) do
    if Issues.issue_matches_filters?(issue,
         project_id: socket.assigns.selected_project_id,
         search: socket.assigns.search_query,
         status: socket.assigns.selected_status,
         last_seen_since: socket.assigns.last_seen_since
       ) do
      issue = Issues.with_project(issue)
      {:noreply, stream_insert(socket, :issues, issue, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-7xl space-y-6">
        <header class="flex flex-col gap-4 border-b border-base-300 pb-5 lg:flex-row lg:items-end lg:justify-between">
          <div class="space-y-2">
            <div>
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
                {@scope_label}
              </p>
              <h1 class="mt-2 text-3xl font-semibold tracking-normal text-base-content">
                Issues
              </h1>
            </div>
          </div>
          <.link
            id="new-project-link"
            navigate={~p"/projects/new"}
            class="inline-flex items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <.icon name="hero-plus" class="size-4" /> New project
          </.link>
        </header>

        <.form
          for={@filter_form}
          id="issue-search-form"
          phx-change="filter"
          phx-submit="filter"
          class="space-y-4 rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm"
        >
          <input type="hidden" name={@filter_form[:project].name} value={@project_filter} />
          <input type="hidden" name={@filter_form[:status].name} value={@status_filter} />
          <input type="hidden" name={@filter_form[:time].name} value={@time_filter} />

          <div class="space-y-1.5">
            <label
              for="filters_q"
              class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/45"
            >
              Search
            </label>
            <div class="relative [&_.fieldset]:mb-0">
              <.icon
                name="hero-magnifying-glass"
                class="pointer-events-none absolute left-3 top-1/2 size-5 -translate-y-1/2 text-base-content/35"
              />
              <.input
                field={@filter_form[:q]}
                type="search"
                placeholder="Search issues, e.g. release:web@1.2.3 environment:prod TypeError"
                autocomplete="off"
                phx-debounce="300"
                aria-label="Search issues by text or key value filters"
                class="h-12 w-full rounded-lg border border-base-300 bg-base-100 pl-10 pr-10 text-sm text-base-content shadow-sm outline-none transition placeholder:text-base-content/35 focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </div>
          </div>

          <div class="grid gap-3 md:grid-cols-[minmax(16rem,1fr)_minmax(11rem,13rem)_minmax(11rem,13rem)_auto] md:items-end">
            <div class="space-y-1.5">
              <span class="block text-xs font-semibold uppercase tracking-[0.14em] text-base-content/45">
                Project
              </span>
              <details
                id="project-filter-menu"
                class="group relative"
                data-close-on-click-away
                phx-click-away={JS.remove_attribute("open")}
                phx-window-keydown={JS.remove_attribute("open")}
                phx-key="escape"
              >
                <summary class={dropdown_summary_class()}>
                  <span class="flex min-w-0 items-center gap-2">
                    <span
                      id="project-filter-selected-logo"
                      class={[
                        "flex size-8 shrink-0 items-center justify-center rounded-md text-xs font-black tracking-normal shadow-sm ring-1 ring-black/5",
                        selected_project_tone_class(@selected_project)
                      ]}
                    >
                      <%= if @selected_project do %>
                        {platform_mark(@selected_project.platform)}
                      <% else %>
                        <.icon name="hero-rectangle-stack" class="size-4" />
                      <% end %>
                    </span>
                    <span class="min-w-0 truncate">{@selected_project_label}</span>
                  </span>
                  <.icon
                    name="hero-chevron-down"
                    class="size-4 shrink-0 text-base-content/45 transition group-open:rotate-180"
                  />
                </summary>

                <div class="absolute left-0 z-20 mt-2 max-h-96 w-full min-w-72 overflow-y-auto rounded-lg border border-base-300 bg-base-100 p-1.5 shadow-xl">
                  <button
                    id="project-filter-option-all"
                    type="button"
                    phx-click="select_project"
                    phx-value-project={@all_projects}
                    class={dropdown_option_class(@project_filter == @all_projects)}
                  >
                    <span class="flex size-9 shrink-0 items-center justify-center rounded-md bg-base-content text-base-100 shadow-sm">
                      <.icon name="hero-rectangle-stack" class="size-4" />
                    </span>
                    <span class="min-w-0 flex-1">
                      <span class="block truncate text-sm font-semibold">All projects</span>
                      <span class="block truncate text-xs text-base-content/45">Every SDK source</span>
                    </span>
                    <.icon
                      :if={@project_filter == @all_projects}
                      name="hero-check"
                      class="size-4 shrink-0"
                    />
                  </button>

                  <button
                    :for={project <- @projects}
                    id={"project-filter-option-#{project.id}"}
                    type="button"
                    phx-click="select_project"
                    phx-value-project={project.id}
                    class={dropdown_option_class(@project_filter == project.id)}
                  >
                    <span
                      id={"project-filter-logo-#{project.id}"}
                      class={[
                        "flex size-9 shrink-0 items-center justify-center rounded-md text-xs font-black tracking-normal shadow-sm ring-1 ring-black/5",
                        platform_tone_class(project.platform)
                      ]}
                    >
                      {platform_mark(project.platform)}
                    </span>
                    <span class="min-w-0 flex-1">
                      <span class="block truncate text-sm font-semibold">{project.name}</span>
                      <span class="block truncate text-xs text-base-content/45">
                        {Projects.project_platform_label(project.platform)}
                      </span>
                    </span>
                    <.icon
                      :if={@project_filter == project.id}
                      name="hero-check"
                      class="size-4 shrink-0"
                    />
                  </button>
                </div>
              </details>
            </div>

            <div class="space-y-1.5">
              <span class="block text-xs font-semibold uppercase tracking-[0.14em] text-base-content/45">
                Status
              </span>
              <details
                id="status-filter-menu"
                class="group relative"
                data-close-on-click-away
                phx-click-away={JS.remove_attribute("open")}
                phx-window-keydown={JS.remove_attribute("open")}
                phx-key="escape"
              >
                <summary class={dropdown_summary_class()}>
                  <span class="min-w-0 truncate">{@selected_status_label}</span>
                  <.icon
                    name="hero-chevron-down"
                    class="size-4 shrink-0 text-base-content/45 transition group-open:rotate-180"
                  />
                </summary>

                <div class="absolute left-0 z-20 mt-2 w-full min-w-48 rounded-lg border border-base-300 bg-base-100 p-1.5 shadow-xl">
                  <button
                    :for={{label, value} <- @status_options}
                    id={"status-filter-option-#{value}"}
                    type="button"
                    phx-click="select_status"
                    phx-value-status={value}
                    class={dropdown_option_class(@status_filter == value)}
                  >
                    <span class="min-w-0 flex-1 truncate text-sm font-semibold">{label}</span>
                    <.icon
                      :if={@status_filter == value}
                      name="hero-check"
                      class="size-4 shrink-0"
                    />
                  </button>
                </div>
              </details>
            </div>

            <div class="space-y-1.5">
              <span class="block text-xs font-semibold uppercase tracking-[0.14em] text-base-content/45">
                Last seen
              </span>
              <details
                id="time-filter-menu"
                class="group relative"
                data-close-on-click-away
                phx-click-away={JS.remove_attribute("open")}
                phx-window-keydown={JS.remove_attribute("open")}
                phx-key="escape"
              >
                <summary class={dropdown_summary_class()}>
                  <span class="min-w-0 truncate">{@selected_time_label}</span>
                  <.icon
                    name="hero-chevron-down"
                    class="size-4 shrink-0 text-base-content/45 transition group-open:rotate-180"
                  />
                </summary>

                <div class="absolute left-0 z-20 mt-2 w-full min-w-48 rounded-lg border border-base-300 bg-base-100 p-1.5 shadow-xl">
                  <button
                    :for={{label, value} <- @time_options}
                    id={"time-filter-option-#{value}"}
                    type="button"
                    phx-click="select_time"
                    phx-value-time={value}
                    class={dropdown_option_class(@time_filter == value)}
                  >
                    <span class="min-w-0 flex-1 truncate text-sm font-semibold">{label}</span>
                    <.icon
                      :if={@time_filter == value}
                      name="hero-check"
                      class="size-4 shrink-0"
                    />
                  </button>
                </div>
              </details>
            </div>

            <button
              id="clear-issue-filters"
              type="button"
              phx-click="clear_filters"
              disabled={!@filters_active?}
              class={[
                "inline-flex h-12 items-center justify-center gap-2 rounded-lg border px-4 text-sm font-semibold shadow-sm transition",
                if(@filters_active?,
                  do:
                    "border-base-300 bg-base-100 text-base-content hover:-translate-y-0.5 hover:shadow-md",
                  else: "cursor-not-allowed border-base-200 bg-base-100 text-base-content/30"
                )
              ]}
            >
              <.icon name="hero-x-mark" class="size-4" /> Clear
            </button>
          </div>
        </.form>

        <section class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm">
          <div class="grid grid-cols-[minmax(0,1fr)_9rem_5rem_5rem_10.5rem] items-center gap-4 border-b border-base-300 px-5 py-3 text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
            <span>Issue</span>
            <span>Status</span>
            <span>Events</span>
            <span>Users</span>
            <span>Last seen</span>
          </div>

          <div id="issues" phx-update="stream" class="divide-y divide-base-300">
            <div id="issues-empty-state" class="hidden px-5 py-12 text-center only:block">
              <p class="font-semibold text-base-content">
                {if @filters_active?, do: "No matching issues", else: "No issues yet"}
              </p>
              <p class="mt-1 text-sm text-base-content/60">
                <%= if @filters_active? do %>
                  Try a different search or project.
                <% else %>
                  Ingested errors will appear here.
                <% end %>
              </p>
            </div>

            <.link
              :for={{id, issue} <- @streams.issues}
              id={id}
              navigate={issue_path(issue)}
              class="grid grid-cols-[minmax(0,1fr)_9rem_5rem_5rem_10.5rem] items-center gap-4 px-5 py-4 transition hover:bg-base-200/70"
            >
              <div class="min-w-0">
                <p class="truncate font-semibold text-base-content">{issue.title}</p>
                <span
                  id={"issue-project-meta-#{issue.id}"}
                  class="mt-2 flex min-w-0 items-center gap-2"
                >
                  <span
                    id={"issue-project-logo-#{issue.id}"}
                    class={[
                      "flex size-5 shrink-0 items-center justify-center rounded-sm text-[0.55rem] font-black tracking-normal shadow-sm ring-1 ring-black/5",
                      issue_project_tone_class(issue)
                    ]}
                  >
                    {issue_project_mark(issue)}
                  </span>
                  <span class="min-w-0 truncate text-sm font-semibold text-base-content/70">
                    {project_name(issue)}
                  </span>
                </span>
              </div>
              <span>
                <span class={status_class(issue.status)}>{issue.status}</span>
              </span>
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
      "inline-flex h-7 w-fit items-center rounded-md bg-red-50 px-2.5 text-xs font-semibold uppercase tracking-[0.08em] text-red-700"

  defp status_class("resolved"),
    do:
      "inline-flex h-7 w-fit items-center rounded-md bg-emerald-50 px-2.5 text-xs font-semibold uppercase tracking-[0.08em] text-emerald-700"

  defp status_class("ignored"),
    do:
      "inline-flex h-7 w-fit items-center rounded-md bg-zinc-100 px-2.5 text-xs font-semibold uppercase tracking-[0.08em] text-zinc-700"

  defp format_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

  defp apply_filters(socket, params) do
    filters = filters_from_params(params, socket.assigns.projects)

    page =
      Issues.paginate_issues(
        limit: @page_size,
        project_id: filters.selected_project_id,
        search: filters.search_query,
        status: filters.selected_status,
        last_seen_since: filters.last_seen_since
      )

    socket
    |> assign(:selected_project, filters.selected_project)
    |> assign(:selected_project_id, filters.selected_project_id)
    |> assign(:selected_project_label, selected_project_label(filters.selected_project))
    |> assign(:project_filter, filters.project_filter)
    |> assign(:scope_label, scope_label(filters.selected_project))
    |> assign(:search_query, filters.search_query)
    |> assign(:status_filter, filters.status_filter)
    |> assign(:selected_status_label, selected_status_label(filters.status_filter))
    |> assign(:selected_status, filters.selected_status)
    |> assign(:time_filter, filters.time_filter)
    |> assign(:selected_time_label, selected_time_label(filters.time_filter))
    |> assign(:last_seen_since, filters.last_seen_since)
    |> assign(
      :filter_form,
      filter_form(
        filters.search_query,
        filters.project_filter,
        filters.status_filter,
        filters.time_filter
      )
    )
    |> assign(
      :filters_active?,
      filters_active?(
        filters.search_query,
        filters.project_filter,
        filters.status_filter,
        filters.time_filter
      )
    )
    |> assign(:next_cursor, page.next_cursor)
    |> stream(:issues, page.issues, reset: true)
  end

  defp filters_from_params(params, projects) do
    selected_project = selected_project(params, projects)
    project_filter = if selected_project, do: selected_project.id, else: @all_projects
    status_filter = normalize_status_filter(Map.get(params, "status"))
    time_filter = normalize_time_filter(Map.get(params, "time"))

    %{
      selected_project: selected_project,
      selected_project_id: selected_project && selected_project.id,
      project_filter: project_filter,
      search_query: normalize_search(Map.get(params, "q", "")),
      status_filter: status_filter,
      selected_status: selected_status(status_filter),
      time_filter: time_filter,
      last_seen_since: last_seen_since(time_filter)
    }
  end

  defp selected_project(%{"project_slug" => slug}, projects) do
    Enum.find(projects, &(&1.slug == slug)) || Projects.get_project_by_slug!(slug)
  end

  defp selected_project(%{"project_id" => id}, projects) do
    Enum.find(projects, &(&1.id == id)) || Projects.get_project!(id)
  end

  defp selected_project(%{"project" => project_id}, projects)
       when project_id not in [nil, "", @all_projects] do
    Enum.find(projects, &(&1.id == project_id))
  end

  defp selected_project(_params, _projects), do: nil

  defp filter_form(search_query, project_filter, status_filter, time_filter) do
    to_form(
      %{
        "q" => search_query,
        "project" => project_filter,
        "status" => status_filter,
        "time" => time_filter
      },
      as: :filters
    )
  end

  defp filters_active?("", @all_projects, @all_statuses, @all_time), do: false
  defp filters_active?(_search_query, _project_filter, _status_filter, _time_filter), do: true

  defp dropdown_summary_class do
    "flex h-12 cursor-pointer list-none items-center justify-between gap-3 rounded-lg border border-base-300 bg-base-100 px-3 text-sm font-semibold text-base-content shadow-sm outline-none transition hover:border-base-content/25 focus-visible:border-primary focus-visible:ring-2 focus-visible:ring-primary/20 [&::-webkit-details-marker]:hidden"
  end

  defp dropdown_option_class(selected?) do
    [
      "flex w-full items-center gap-3 rounded-md px-2.5 py-2 text-left transition hover:bg-base-200",
      selected? && "bg-primary/10 text-primary"
    ]
  end

  defp issues_index_path(filter_params) do
    search_query = normalize_search(Map.get(filter_params, "q", ""))
    project_filter = normalize_project_filter(Map.get(filter_params, "project"))
    status_filter = normalize_status_filter(Map.get(filter_params, "status"))
    time_filter = normalize_time_filter(Map.get(filter_params, "time"))

    query =
      %{"project" => project_filter}
      |> maybe_put_query("q", search_query)
      |> maybe_put_query("status", status_filter, @all_statuses)
      |> maybe_put_query("time", time_filter, @all_time)

    ~p"/issues?#{query}"
  end

  defp maybe_put_query(query, _key, ""), do: query
  defp maybe_put_query(query, key, value), do: Map.put(query, key, value)
  defp maybe_put_query(query, _key, value, value), do: query
  defp maybe_put_query(query, key, value, _default), do: Map.put(query, key, value)

  defp normalize_project_filter(project_filter) when project_filter in [nil, ""],
    do: @all_projects

  defp normalize_project_filter(project_filter), do: project_filter

  defp normalize_status_filter(status) when status in ["unresolved", "resolved", "ignored"],
    do: status

  defp normalize_status_filter(_status), do: @all_statuses

  defp normalize_time_filter(time_filter) when time_filter in ["24h", "7d", "30d"],
    do: time_filter

  defp normalize_time_filter(_time_filter), do: @all_time

  defp selected_status(@all_statuses), do: nil
  defp selected_status(status), do: status

  defp selected_status_label(status_filter), do: option_label(@status_options, status_filter)

  defp last_seen_since(@all_time), do: nil

  defp last_seen_since("24h"), do: DateTime.add(DateTime.utc_now(), -24 * 60 * 60, :second)
  defp last_seen_since("7d"), do: DateTime.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)

  defp last_seen_since("30d"), do: DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

  defp selected_time_label(time_filter), do: option_label(@time_options, time_filter)

  defp option_label(options, value) do
    options
    |> Enum.find(fn {_label, option_value} -> option_value == value end)
    |> case do
      {label, _value} -> label
      nil -> value
    end
  end

  defp scope_label(nil), do: "All projects"
  defp scope_label(project), do: project.name

  defp selected_project_label(nil), do: "All projects"
  defp selected_project_label(project), do: project.name

  defp project_name(%{project: %Ecto.Association.NotLoaded{}}), do: "Unknown"
  defp project_name(%{project: nil}), do: "Unknown"
  defp project_name(%{project: project}), do: project.name

  defp issue_project_mark(%{project: %Ecto.Association.NotLoaded{}}), do: "?"
  defp issue_project_mark(%{project: nil}), do: "?"
  defp issue_project_mark(%{project: project}), do: platform_mark(project.platform)

  defp issue_project_tone_class(%{project: %Ecto.Association.NotLoaded{}}),
    do: platform_tone_class(nil)

  defp issue_project_tone_class(%{project: nil}), do: platform_tone_class(nil)
  defp issue_project_tone_class(%{project: project}), do: platform_tone_class(project.platform)

  defp selected_project_tone_class(nil), do: "bg-base-content text-base-100"
  defp selected_project_tone_class(project), do: platform_tone_class(project.platform)

  defp platform_mark(platform_id) do
    platform_id
    |> platform_metadata()
    |> Map.get(:mark, "?")
  end

  defp platform_tone_class(platform_id) do
    platform_id
    |> platform_metadata()
    |> Map.get(:tone, "bg-base-300 text-base-content")
  end

  defp platform_metadata(platform_id) do
    Enum.find(
      Projects.project_platforms(),
      %{mark: "?", tone: "bg-base-300 text-base-content"},
      fn
        %{id: ^platform_id} -> true
        _platform -> false
      end
    )
  end

  defp issue_path(%{project: project} = issue) do
    ~p"/p/#{project.slug}/issues/#{issue.id}"
  end

  defp normalize_search(search_query) when is_binary(search_query), do: String.trim(search_query)
  defp normalize_search(_search_query), do: ""
end
