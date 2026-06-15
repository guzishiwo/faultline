defmodule FaultlineWeb.IssueLive.Index do
  use FaultlineWeb, :live_view

  alias Faultline.Issues
  alias Faultline.Projects

  @page_size 20

  @impl true
  def mount(params, _session, socket) do
    project = Projects.get_project_by_route_param!(params)
    search_query = normalize_search(Map.get(params, "q", ""))
    page = Issues.paginate_project_issues(project.id, limit: @page_size, search: search_query)

    if connected?(socket), do: Issues.subscribe(project.id)

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:search_query, search_query)
     |> assign(:search_form, search_form(search_query))
     |> assign(:next_cursor, page.next_cursor)
     |> stream(:issues, page.issues, reset: true)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"q" => search_query}}, socket) do
    {:noreply, reset_issues(socket, search_query)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, reset_issues(socket, "")}
  end

  def handle_event("load_more", _params, socket) do
    page =
      Issues.paginate_project_issues(socket.assigns.project.id,
        limit: @page_size,
        after: socket.assigns.next_cursor,
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
    if issue.project_id == socket.assigns.project.id and
         Issues.issue_matches_search?(issue, socket.assigns.search_query) do
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

        <.form
          for={@search_form}
          id="issue-search-form"
          phx-change="search"
          phx-submit="search"
          class="flex flex-col gap-3 sm:flex-row sm:items-start"
        >
          <div class="relative flex-1">
            <.icon
              name="hero-magnifying-glass"
              class="pointer-events-none absolute left-3 top-3 size-5 text-base-content/35"
            />
            <.input
              field={@search_form[:q]}
              type="search"
              placeholder="Search by title or fingerprint"
              autocomplete="off"
              phx-debounce="300"
              aria-label="Search issues"
              class="w-full rounded-lg border border-base-300 bg-base-100 py-2.5 pl-10 pr-3 text-sm text-base-content shadow-sm outline-none transition placeholder:text-base-content/35 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20"
            />
          </div>
          <button
            :if={@search_query != ""}
            id="clear-issue-search"
            type="button"
            phx-click="clear_search"
            class="inline-flex items-center justify-center gap-2 rounded-lg border border-base-300 bg-base-100 px-4 py-2.5 text-sm font-semibold text-base-content shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <.icon name="hero-x-mark" class="size-4" /> Clear
          </button>
        </.form>

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
              <p class="font-semibold text-base-content">
                {if @search_query == "", do: "No issues yet", else: "No matching issues"}
              </p>
              <p class="mt-1 text-sm text-base-content/60">
                <%= if @search_query == "" do %>
                  Ingested errors will appear here.
                <% else %>
                  Try a different title or fingerprint.
                <% end %>
              </p>
            </div>

            <.link
              :for={{id, issue} <- @streams.issues}
              id={id}
              navigate={~p"/p/#{@project.slug}/issues/#{issue.id}"}
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

  defp reset_issues(socket, search_query) do
    search_query = normalize_search(search_query)

    page =
      Issues.paginate_project_issues(socket.assigns.project.id,
        limit: @page_size,
        search: search_query
      )

    socket
    |> assign(:search_query, search_query)
    |> assign(:search_form, search_form(search_query))
    |> assign(:next_cursor, page.next_cursor)
    |> stream(:issues, page.issues, reset: true)
  end

  defp search_form(search_query), do: to_form(%{"q" => search_query}, as: :search)

  defp normalize_search(search_query) when is_binary(search_query), do: String.trim(search_query)
  defp normalize_search(_search_query), do: ""
end
