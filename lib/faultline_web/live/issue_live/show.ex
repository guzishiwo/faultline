defmodule FaultlineWeb.IssueLive.Show do
  use FaultlineWeb, :live_view

  alias Faultline.Events
  alias Faultline.Issues
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
              navigate={~p"/p/#{@project.slug}/issues"}
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
                  {occurrence_title(event)}
                </span>
                <span class="mt-1 block text-xs text-base-content/55">
                  {event.release || "unknown release"}
                </span>
                <span class="mt-1 flex items-center justify-between gap-2 text-xs text-base-content/55">
                  <span>{event.environment || "unknown env"}</span>
                  <span>{format_time(event.occurred_at)}</span>
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
                      "unknown"} &middot; {format_time(@selected_event.occurred_at)}
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
                <section id="event-overview" class="grid gap-4">
                  <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
                    Overview
                  </h3>
                  <dl class="grid gap-x-5 gap-y-3 text-sm sm:grid-cols-2 xl:grid-cols-3">
                    <.kv label="Exception" value={compact_exception(@selected_event)} />
                    <.kv label="Mechanism" value={mechanism_summary(@selected_event)} />
                    <.kv label="Culprit" value={@selected_event.culprit} />
                    <.kv label="Release" value={@selected_event.release} />
                    <.kv label="Environment" value={@selected_event.environment} />
                    <.kv label="Server" value={@selected_event.server_name} />
                    <.kv label="User" value={@selected_event.user_identifier} />
                    <.kv label="Request" value={@selected_event.request_url} />
                    <.kv label="Trace" value={trace_summary(@selected_event)} />
                  </dl>
                </section>

                <.stacktrace
                  frames={get_in(@selected_event.details, ["exception", "stacktrace_frames"]) || []}
                  event_id={@selected_event.id}
                />

                <section id="event-context" class="grid gap-5 border-t border-base-300 pt-5">
                  <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
                    Context
                  </h3>
                  <div class="grid gap-5 lg:grid-cols-2">
                    <.map_section title="Tags" values={@selected_event.details["tags"] || %{}} />
                    <.map_section title="User" values={@selected_event.details["user"] || %{}} />
                    <.map_section title="Request" values={@selected_event.details["request"] || %{}} />
                    <.context_cards contexts={@selected_event.details["contexts"] || %{}} />
                  </div>
                </section>

                <section id="event-sdk" class="grid gap-5 border-t border-base-300 pt-5">
                  <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
                    SDK and runtime
                  </h3>
                  <div class="grid gap-5 lg:grid-cols-2">
                    <.map_section title="SDK" values={sdk_summary(@selected_event)} />
                    <.modules values={@selected_event.details["modules"] || %{}} />
                  </div>
                </section>

                <section id="event-breadcrumbs" class="border-t border-base-300 pt-5">
                  <.breadcrumbs values={@selected_event.details["breadcrumbs"] || []} />
                </section>
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
                >{raw_event_json(@raw_event_payload)}</code></pre>
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

  attr :label, :string, required: true
  attr :value, :any, default: nil

  defp kv(assigns) do
    ~H"""
    <div class="min-w-0">
      <dt class="text-base-content/50">{@label}</dt>
      <dd class="mt-1 break-words font-medium text-base-content">{@value || "-"}</dd>
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
          <span class="break-words text-base-content/50">{key}</span>
          <span class="break-words font-medium text-base-content">{format_detail(value)}</span>
        </div>
      </div>
    </section>
    """
  end

  attr :contexts, :map, required: true

  defp context_cards(assigns) do
    assigns = assign(assigns, :visible_contexts, visible_contexts(assigns.contexts))

    ~H"""
    <section id="event-contexts" class="lg:col-span-2">
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        Contexts
      </h3>
      <div class="mt-2 grid gap-3 lg:grid-cols-2">
        <p :if={@visible_contexts == []} class="text-sm text-base-content/50">None</p>
        <article
          :for={{name, values} <- @visible_contexts}
          id={"event-context-#{name}"}
          class="rounded-lg border border-base-300 bg-base-200/50 p-3"
        >
          <h4 class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-base-content/50">
            {name}
          </h4>
          <dl class="mt-2 grid gap-1 text-sm">
            <div :for={{key, value} <- values} class="grid grid-cols-[7rem_minmax(0,1fr)] gap-2">
              <dt class="break-words text-base-content/50">{key}</dt>
              <dd class="break-words font-medium text-base-content">{format_detail(value)}</dd>
            </div>
          </dl>
        </article>
      </div>
    </section>
    """
  end

  attr :values, :map, required: true

  defp modules(assigns) do
    assigns = assign(assigns, :modules, sorted_take(assigns.values, 12))

    ~H"""
    <section id="event-modules">
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        Modules
      </h3>
      <div class="mt-2 grid gap-1 text-sm">
        <p :if={@modules == []} class="text-base-content/50">None</p>
        <div :for={{name, version} <- @modules} class="grid grid-cols-[minmax(0,1fr)_7rem] gap-2">
          <span class="truncate font-mono text-xs text-base-content/70">{name}</span>
          <span class="truncate text-right font-mono text-xs text-base-content/50">{version}</span>
        </div>
      </div>
    </section>
    """
  end

  attr :frames, :list, required: true
  attr :event_id, :string, required: true

  defp stacktrace(assigns) do
    ~H"""
    <section>
      <h3 class="text-xs font-semibold uppercase tracking-[0.14em] text-base-content/50">
        Stacktrace
      </h3>
      <div class="stacktrace-list mt-2 overflow-hidden rounded-lg border border-base-300 bg-base-200/60">
        <p :if={@frames == []} class="p-3 text-sm text-base-content/50">No frames</p>
        <div
          :for={{frame, index} <- Enum.with_index(Enum.reverse(@frames), 1)}
          id={"stack-frame-#{index}"}
          class="grid gap-3 border-b border-base-300 px-3 py-3 last:border-b-0 md:grid-cols-[2.5rem_minmax(0,1fr)]"
        >
          <div class="font-mono text-xs text-base-content/40 md:pt-1">
            #{index}
          </div>
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <p class="break-words font-mono text-sm font-semibold text-base-content">
                {frame["function"] || frame["module"] || "anonymous"}
              </p>
              <span
                :if={frame["in_app"]}
                class="rounded border border-error/20 bg-error/10 px-1.5 py-0.5 text-[0.65rem] font-semibold uppercase tracking-[0.12em] text-error"
              >
                app
              </span>
            </div>
            <p class="mt-1 break-words font-mono text-xs leading-5 text-base-content/55">
              {frame_location(frame)}
            </p>
            <.frame_source frame={frame} index={index} event_id={@event_id} />
            <.frame_vars frame={frame} index={index} />
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :frame, :map, required: true
  attr :index, :integer, required: true
  attr :event_id, :string, required: true

  defp frame_source(assigns) do
    assigns =
      assigns
      |> assign(:lines, frame_source_lines(assigns.frame))
      |> assign(:language, frame_language(assigns.frame))

    ~H"""
    <div
      :if={@lines != []}
      id={"stack-frame-#{@index}-source"}
      class="mt-3 overflow-x-auto rounded-lg border border-base-300 bg-base-100"
    >
      <div
        :for={line <- @lines}
        id={"stack-frame-#{@index}-source-line-#{line.id}"}
        class={[
          "grid grid-cols-[3.5rem_minmax(0,1fr)] font-mono text-xs leading-6",
          line.current? && "bg-orange-500/10 text-base-content",
          !line.current? && "text-base-content/65"
        ]}
      >
        <span class="select-none border-r border-base-300 px-3 text-right text-base-content/40">
          {line.number}
        </span>
        <code
          id={"stack-frame-#{@event_id}-#{@index}-source-line-#{line.id}-code"}
          phx-hook={if(@language, do: "CodeHighlight")}
          phx-update={if(@language, do: "ignore")}
          data-prism-language={@language}
          class={["min-w-max whitespace-pre px-3", @language && "language-#{@language}"]}
        >{line.source}</code>
      </div>
    </div>
    """
  end

  attr :frame, :map, required: true
  attr :index, :integer, required: true

  defp frame_vars(assigns) do
    assigns = assign(assigns, :vars, frame_var_pairs(assigns.frame))

    ~H"""
    <div
      :if={@vars != []}
      id={"stack-frame-#{@index}-vars"}
      class="mt-3 overflow-hidden rounded-lg border border-base-300 bg-base-100"
    >
      <div
        :for={{name, value} <- @vars}
        id={"stack-frame-#{@index}-var-#{dom_id_part(name)}"}
        class="grid border-b border-base-300 text-xs last:border-b-0 sm:grid-cols-[10rem_minmax(0,1fr)]"
      >
        <span class="border-b border-base-300 px-3 py-2 font-mono font-semibold text-base-content/70 sm:border-b-0 sm:border-r">
          {name}
        </span>
        <code class="break-words px-3 py-2 font-mono text-base-content/65">{format_detail(value)}</code>
      </div>
    </div>
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

  defp find_event(events, event_id) do
    with {:ok, id} <- Ecto.UUID.cast(event_id) do
      Enum.find(events, &(&1.id == id))
    else
      _ -> nil
    end
  end

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

  defp occurrence_title(event) do
    compact_exception(event) || event.message || "Event"
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

  defp mechanism_summary(event) do
    mechanism = get_in(event.details, ["exception", "mechanism"]) || %{}

    case {mechanism["type"], mechanism["handled"]} do
      {nil, nil} -> nil
      {type, nil} -> type
      {nil, handled} -> "handled=#{handled}"
      {type, handled} -> "#{type}, handled=#{handled}"
    end
  end

  defp trace_summary(event) do
    trace = get_in(event.details, ["contexts", "trace"]) || %{}

    cond do
      is_binary(trace["trace_id"]) and is_binary(trace["span_id"]) ->
        "#{trace["trace_id"]} / #{trace["span_id"]}"

      is_binary(trace["trace_id"]) ->
        trace["trace_id"]

      true ->
        nil
    end
  end

  defp sdk_summary(event) do
    sdk = event.details["sdk"] || %{}

    %{
      "name" => sdk["name"],
      "version" => sdk["version"],
      "packages" => package_summary(sdk["packages"]),
      "integrations" => integration_summary(sdk["integrations"])
    }
    |> Enum.reject(fn {_key, value} -> blank_detail?(value) end)
    |> Map.new()
  end

  defp package_summary(packages) when is_list(packages) do
    packages
    |> Enum.take(3)
    |> Enum.map(fn
      %{"name" => name, "version" => version} -> "#{name}@#{version}"
      value -> format_detail(value)
    end)
    |> Enum.join(", ")
  end

  defp package_summary(_packages), do: nil

  defp integration_summary(integrations) when is_list(integrations) do
    count = length(integrations)

    integrations
    |> Enum.take(8)
    |> Enum.join(", ")
    |> then(fn summary ->
      if count > 8, do: "#{summary}, +#{count - 8} more", else: summary
    end)
  end

  defp integration_summary(_integrations), do: nil

  defp visible_contexts(contexts) when is_map(contexts) do
    contexts
    |> Map.take(~w(app runtime os device culture cloud_resource trace))
    |> Enum.reject(fn {_name, values} -> blank_detail?(values) end)
    |> Enum.map(fn {name, values} -> {name, values |> flatten_context() |> sorted_take(8)} end)
    |> Enum.reject(fn {_name, values} -> values == [] end)
    |> Enum.sort_by(fn {name, _values} -> context_order(name) end)
  end

  defp visible_contexts(_contexts), do: []

  defp flatten_context(values) when is_map(values) do
    values
    |> Enum.reject(fn {_key, value} -> blank_detail?(value) end)
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
  end

  defp flatten_context(_values), do: []

  defp sorted_take(values, count) when is_map(values) do
    values
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> sorted_take(count)
  end

  defp sorted_take(values, count) when is_list(values) do
    values
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.take(count)
  end

  defp sorted_take(_values, _count), do: []

  defp context_order("app"), do: 1
  defp context_order("runtime"), do: 2
  defp context_order("os"), do: 3
  defp context_order("device"), do: 4
  defp context_order("culture"), do: 5
  defp context_order("trace"), do: 6
  defp context_order(_name), do: 99

  defp format_detail(value) when is_binary(value), do: value
  defp format_detail(value) when is_integer(value), do: Integer.to_string(value)
  defp format_detail(value) when is_float(value), do: Float.to_string(value)
  defp format_detail(value) when is_boolean(value), do: to_string(value)

  defp format_detail(value) when is_list(value),
    do: value |> Enum.map(&format_detail/1) |> Enum.join(", ")

  defp format_detail(value), do: inspect(value)

  defp blank_detail?(nil), do: true
  defp blank_detail?(""), do: true
  defp blank_detail?(value) when is_map(value), do: map_size(value) == 0
  defp blank_detail?(value) when is_list(value), do: value == []
  defp blank_detail?(_value), do: false

  defp frame_location(frame) do
    filename = frame["filename"] || frame["abs_path"] || "unknown"
    line = frame["lineno"] || "?"
    column = frame["colno"]

    if column do
      "#{filename}:#{line}:#{column}"
    else
      "#{filename}:#{line}"
    end
  end

  defp frame_source_lines(frame) do
    pre_context = list_value(frame["pre_context"])
    context_line = frame["context_line"]
    post_context = list_value(frame["post_context"])

    case {pre_context, context_line, post_context} do
      {[], nil, []} ->
        []

      _ ->
        current_line_number = integer_value(frame["lineno"])
        first_line_number = first_source_line_number(current_line_number, length(pre_context))

        pre_context
        |> Enum.concat(List.wrap(context_line))
        |> Enum.concat(post_context)
        |> Enum.with_index()
        |> Enum.map(fn {source, index} ->
          source_line_number = source_line_number(first_line_number, index)

          %{
            id: index + 1,
            number: source_line_number || "",
            source: source,
            current?: current_line_number != nil and source_line_number == current_line_number
          }
        end)
    end
  end

  defp frame_var_pairs(%{"vars" => vars}) when is_map(vars) do
    sorted_take(vars, 16)
  end

  defp frame_var_pairs(_frame), do: []

  defp frame_language(frame) do
    frame
    |> frame_filename()
    |> Path.extname()
    |> String.downcase()
    |> case do
      ".py" -> "python"
      ".pyw" -> "python"
      ".js" -> "javascript"
      ".mjs" -> "javascript"
      ".cjs" -> "javascript"
      ".jsx" -> "jsx"
      ".ts" -> "typescript"
      ".mts" -> "typescript"
      ".cts" -> "typescript"
      ".tsx" -> "tsx"
      ".rb" -> "ruby"
      ".php" -> "php"
      ".java" -> "java"
      ".kt" -> "kotlin"
      ".kts" -> "kotlin"
      ".cs" -> "csharp"
      ".go" -> "go"
      ".rs" -> "rust"
      ".swift" -> "swift"
      ".m" -> "objectivec"
      ".mm" -> "objectivec"
      ".dart" -> "dart"
      ".c" -> "c"
      ".h" -> "c"
      ".cc" -> "cpp"
      ".cpp" -> "cpp"
      ".cxx" -> "cpp"
      ".hpp" -> "cpp"
      ".hh" -> "cpp"
      ".hxx" -> "cpp"
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".json" -> "json"
      _ -> nil
    end
  end

  defp frame_filename(frame), do: frame["filename"] || frame["abs_path"] || ""

  defp first_source_line_number(nil, _pre_context_count), do: nil

  defp first_source_line_number(line_number, pre_context_count),
    do: line_number - pre_context_count

  defp source_line_number(nil, _index), do: nil
  defp source_line_number(first_line_number, index), do: first_line_number + index

  defp list_value(value) when is_list(value) do
    Enum.filter(value, &is_binary/1)
  end

  defp list_value(_value), do: []

  defp integer_value(value) when is_integer(value), do: value
  defp integer_value(_value), do: nil

  defp dom_id_part(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "value"
      value -> value
    end
  end

  defp raw_event_json(value), do: Jason.encode!(value, pretty: true)

  defp format_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
end
