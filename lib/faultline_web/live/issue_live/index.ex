defmodule FaultlineWeb.IssueLive.Index do
  use FaultlineWeb, :live_view

  alias Faultline.Issues
  alias Faultline.Projects

  @page_size 20
  @all_projects "-1"

  @impl true
  def mount(params, _session, socket) do
    projects = Projects.list_projects()

    if connected?(socket), do: Issues.subscribe_all()

    {:ok,
     socket
     |> assign(:projects, projects)
     |> assign(:project_options, project_options(projects))
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

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     push_patch(socket,
       to: issues_index_path(%{"q" => "", "project" => socket.assigns.project_filter})
     )}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: issues_index_path(%{"q" => "", "project" => @all_projects}))}
  end

  def handle_event("load_more", _params, socket) do
    page =
      Issues.paginate_issues(
        limit: @page_size,
        after: socket.assigns.next_cursor,
        project_id: socket.assigns.selected_project_id,
        search: socket.assigns.search_query
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
         search: socket.assigns.search_query
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
            <.link
              id="back-to-projects-link"
              navigate={~p"/projects"}
              class="inline-flex items-center gap-2 text-sm font-semibold text-base-content/60 transition hover:text-base-content"
            >
              <.icon name="hero-rectangle-stack" class="size-4" /> Manage projects
            </.link>
            <div>
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-orange-600">
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
          class={[
            "grid gap-3 rounded-lg border border-base-300 bg-base-100 p-4 shadow-sm md:items-center",
            if(@filters_active?,
              do: "md:grid-cols-[minmax(0,1fr)_20rem_auto]",
              else: "md:grid-cols-[minmax(0,1fr)_20rem]"
            )
          ]}
        >
          <div class="relative [&_.fieldset]:mb-0">
            <.icon
              name="hero-magnifying-glass"
              class="pointer-events-none absolute left-3 top-3.5 size-5 text-base-content/35"
            />
            <.input
              field={@filter_form[:q]}
              type="search"
              placeholder="Search issues by title or fingerprint"
              autocomplete="off"
              phx-debounce="300"
              aria-label="Search issues"
              class="h-12 w-full rounded-lg border border-base-300 bg-base-100 pl-10 pr-10 text-sm text-base-content shadow-sm outline-none transition placeholder:text-base-content/35 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20"
            />
          </div>
          <div class="[&_.fieldset]:mb-0">
            <.input
              field={@filter_form[:project]}
              type="select"
              options={@project_options}
              aria-label="Filter by project"
              class="h-12 w-full rounded-lg border border-base-300 bg-base-100 px-3 pr-9 text-sm text-base-content shadow-sm outline-none transition focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20"
            />
          </div>
          <button
            :if={@filters_active?}
            id="clear-issue-filters"
            type="button"
            phx-click="clear_filters"
            class="inline-flex h-12 items-center justify-center gap-2 rounded-lg border border-base-300 bg-base-100 px-4 text-sm font-semibold text-base-content shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <.icon name="hero-x-mark" class="size-4" /> Clear
          </button>
        </.form>

        <section class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm">
          <div class="grid grid-cols-[minmax(0,1fr)_10rem_9rem_5rem_5rem_10.5rem] items-center gap-4 border-b border-base-300 px-5 py-3 text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
            <span>Issue</span>
            <span>Project</span>
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
              class="grid grid-cols-[minmax(0,1fr)_10rem_9rem_5rem_5rem_10.5rem] items-center gap-4 px-5 py-4 transition hover:bg-base-200/70"
            >
              <div class="min-w-0">
                <p class="truncate font-semibold text-base-content">{issue.title}</p>
                <p class="mt-1 truncate font-mono text-xs text-base-content/45">
                  {issue.fingerprint}
                </p>
              </div>
              <span class="min-w-0 truncate text-sm font-semibold text-base-content/70">
                {project_name(issue)}
              </span>
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
        search: filters.search_query
      )

    socket
    |> assign(:selected_project, filters.selected_project)
    |> assign(:selected_project_id, filters.selected_project_id)
    |> assign(:project_filter, filters.project_filter)
    |> assign(:scope_label, scope_label(filters.selected_project))
    |> assign(:search_query, filters.search_query)
    |> assign(:filter_form, filter_form(filters.search_query, filters.project_filter))
    |> assign(:filters_active?, filters_active?(filters.search_query, filters.project_filter))
    |> assign(:next_cursor, page.next_cursor)
    |> stream(:issues, page.issues, reset: true)
  end

  defp filters_from_params(params, projects) do
    selected_project = selected_project(params, projects)
    project_filter = if selected_project, do: selected_project.id, else: @all_projects

    %{
      selected_project: selected_project,
      selected_project_id: selected_project && selected_project.id,
      project_filter: project_filter,
      search_query: normalize_search(Map.get(params, "q", ""))
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

  defp filter_form(search_query, project_filter) do
    to_form(%{"q" => search_query, "project" => project_filter}, as: :filters)
  end

  defp project_options(projects) do
    [{"All projects", @all_projects} | Enum.map(projects, &{&1.name, &1.id})]
  end

  defp filters_active?("", @all_projects), do: false
  defp filters_active?(_search_query, _project_filter), do: true

  defp issues_index_path(filter_params) do
    search_query = normalize_search(Map.get(filter_params, "q", ""))
    project_filter = normalize_project_filter(Map.get(filter_params, "project"))

    query =
      %{"project" => project_filter}
      |> maybe_put_query("q", search_query)

    ~p"/issues?#{query}"
  end

  defp maybe_put_query(query, _key, ""), do: query
  defp maybe_put_query(query, key, value), do: Map.put(query, key, value)

  defp normalize_project_filter(project_filter) when project_filter in [nil, ""],
    do: @all_projects

  defp normalize_project_filter(project_filter), do: project_filter

  defp scope_label(nil), do: "All projects"
  defp scope_label(project), do: project.name

  defp project_name(%{project: %Ecto.Association.NotLoaded{}}), do: "Unknown"
  defp project_name(%{project: nil}), do: "Unknown"
  defp project_name(%{project: project}), do: project.name

  defp issue_path(%{project: project} = issue) do
    ~p"/p/#{project.slug}/issues/#{issue.id}"
  end

  defp normalize_search(search_query) when is_binary(search_query), do: String.trim(search_query)
  defp normalize_search(_search_query), do: ""
end
