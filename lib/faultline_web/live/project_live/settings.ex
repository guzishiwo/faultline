defmodule FaultlineWeb.ProjectLive.Settings do
  use FaultlineWeb, :live_view

  alias Faultline.Alerts
  alias Faultline.Alerts.AlertRule
  alias Faultline.Projects
  alias Faultline.Retention
  alias Faultline.Retention.ProjectDropRule

  @notify_on_options [
    {"New issues", "new_issue"},
    {"Regressions", "regression"},
    {"Frequency alerts", "frequency"}
  ]

  @channel_options [
    {"Email", "email"},
    {"Webhook", "webhook"},
    {"Slack webhook", "slack"}
  ]

  @drop_rule_field_options [
    {"Exception type", "exception_type"},
    {"Message", "message"},
    {"Culprit", "culprit"},
    {"Logger", "logger"},
    {"Level", "level"},
    {"Environment", "environment"},
    {"Release", "release"}
  ]

  @drop_rule_type_options [
    {"Contains", "contains"},
    {"Equals", "equals"}
  ]

  @impl true
  def mount(params, _session, socket) do
    project = Projects.get_project_by_route_param!(params)
    rules = Alerts.list_project_alert_rules(project.id)
    drop_rules = Retention.list_project_drop_rules(project.id)

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:editing_rule, nil)
     |> assign(:notify_on_options, @notify_on_options)
     |> assign(:channel_options, @channel_options)
     |> assign(:drop_rule_field_options, @drop_rule_field_options)
     |> assign(:drop_rule_type_options, @drop_rule_type_options)
     |> assign_project_form(Projects.change_project_settings(project))
     |> assign_drop_form(new_drop_rule_changeset(project))
     |> assign_form(new_rule_changeset(project))
     |> stream(:drop_rules, drop_rules, dom_id: &"drop-rules-#{&1.id}")
     |> stream(:alert_rules, rules, dom_id: &"alert-rules-#{&1.id}")}
  end

  @impl true
  def handle_event("validate_project_settings", %{"project" => params}, socket) do
    changeset =
      socket.assigns.project
      |> Projects.change_project_settings(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_project_form(socket, changeset)}
  end

  def handle_event("save_project_settings", %{"project" => params}, socket) do
    case Projects.update_project_settings(socket.assigns.project, params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project cost controls updated.")
         |> assign(:project, project)
         |> assign_project_form(Projects.change_project_settings(project))}

      {:error, changeset} ->
        {:noreply, assign_project_form(socket, Map.put(changeset, :action, :update))}
    end
  end

  def handle_event("validate_drop_rule", %{"project_drop_rule" => params}, socket) do
    changeset =
      %ProjectDropRule{}
      |> drop_rule_changeset(socket.assigns.project, params)
      |> Map.put(:action, :validate)

    {:noreply, assign_drop_form(socket, changeset)}
  end

  def handle_event("save_drop_rule", %{"project_drop_rule" => params}, socket) do
    case Retention.create_drop_rule(socket.assigns.project, params) do
      {:ok, drop_rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Drop rule created.")
         |> assign_drop_form(new_drop_rule_changeset(socket.assigns.project))
         |> stream_insert(:drop_rules, drop_rule, at: 0)}

      {:error, changeset} ->
        {:noreply, assign_drop_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("toggle_drop_rule", %{"id" => id}, socket) do
    drop_rule = Retention.get_project_drop_rule!(socket.assigns.project.id, id)

    case Retention.update_drop_rule(drop_rule, drop_rule_toggle_attrs(drop_rule)) do
      {:ok, drop_rule} ->
        {:noreply, stream_insert(socket, :drop_rules, drop_rule)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update drop rule.")}
    end
  end

  def handle_event("delete_drop_rule", %{"id" => id}, socket) do
    drop_rule = Retention.get_project_drop_rule!(socket.assigns.project.id, id)
    {:ok, _drop_rule} = Retention.delete_drop_rule(drop_rule)

    {:noreply, stream_delete(socket, :drop_rules, drop_rule)}
  end

  def handle_event("validate", %{"alert_rule" => params}, socket) do
    changeset =
      form_rule(socket.assigns)
      |> rule_changeset(socket.assigns.project, params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"alert_rule" => params}, socket) do
    case socket.assigns.editing_rule do
      nil -> create_rule(socket, params)
      %AlertRule{} = rule -> update_rule(socket, rule, params)
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    rule = Alerts.get_project_alert_rule!(socket.assigns.project.id, id)

    {:noreply,
     socket
     |> assign(:editing_rule, rule)
     |> assign_form(Alerts.change_alert_rule(rule))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_rule, nil)
     |> assign_form(new_rule_changeset(socket.assigns.project))}
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    rule = Alerts.get_project_alert_rule!(socket.assigns.project.id, id)

    case Alerts.update_alert_rule(rule, toggle_attrs(rule)) do
      {:ok, rule} ->
        {:noreply, stream_insert(socket, :alert_rules, rule)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update alert rule.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    rule = Alerts.get_project_alert_rule!(socket.assigns.project.id, id)
    {:ok, _rule} = Alerts.delete_alert_rule(rule)

    {:noreply,
     socket
     |> stream_delete(:alert_rules, rule)
     |> maybe_reset_deleted_editor(rule)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="project-settings-page" class="mx-auto w-full max-w-7xl space-y-6">
        <header class="flex flex-col gap-4 border-b border-base-300 pb-5 lg:flex-row lg:items-start lg:justify-between">
          <div class="min-w-0 space-y-3">
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
                Project settings
              </h1>
            </div>
          </div>

          <div class="flex flex-wrap gap-2">
            <.link
              id="project-usage-link"
              navigate={~p"/p/#{@project.slug}/usage"}
              class="inline-flex w-fit items-center gap-2 rounded-lg border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content/70 transition hover:-translate-y-0.5 hover:bg-base-200 hover:text-base-content"
            >
              Usage <.icon name="hero-chart-bar" class="size-4" />
            </.link>
            <.link
              id="project-issues-link"
              navigate={~p"/p/#{@project.slug}/issues"}
              class="inline-flex w-fit items-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
            >
              Open triage <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </header>

        <section class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_18rem]">
          <section
            id="project-sdk-settings"
            class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
          >
            <div class="flex items-start gap-3">
              <div class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-orange-100 text-orange-700">
                <.icon name="hero-key" class="size-5" />
              </div>
              <div class="min-w-0 flex-1">
                <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
                  SDK DSN
                </h2>
                <code
                  id="project-dsn"
                  class="mt-3 block max-h-28 overflow-auto rounded-md border border-base-300 bg-base-200 px-3 py-2 font-mono text-xs text-base-content"
                >
                  {@project.dsn}
                </code>
              </div>
            </div>
          </section>

          <section
            id="project-ingest-settings"
            class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
          >
            <div class="flex size-10 items-center justify-center rounded-lg bg-base-200 text-base-content/70">
              <.icon name="hero-bolt" class="size-5" />
            </div>
            <h2 class="mt-4 text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Ingest limit
            </h2>
            <p class="mt-3 text-2xl font-semibold text-base-content">
              {@project.rate_limit_max_events}
            </p>
            <p class="text-sm text-base-content/60">
              events per {@project.rate_limit_window_seconds}s
            </p>
          </section>
        </section>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_24rem]">
          <section
            id="project-cost-controls"
            class="rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
          >
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Cost controls
            </h2>

            <.form
              for={@project_form}
              id="project-cost-controls-form"
              phx-change="validate_project_settings"
              phx-submit="save_project_settings"
              class="mt-5 grid gap-4 sm:grid-cols-2"
            >
              <.input
                field={@project_form[:rate_limit_max_events]}
                type="number"
                label="Rate limit events"
                min="1"
                max="1000000"
                required
              />
              <.input
                field={@project_form[:rate_limit_window_seconds]}
                type="number"
                label="Rate limit window seconds"
                min="1"
                max="86400"
                required
              />
              <.input
                field={@project_form[:retention_days]}
                type="number"
                label="Retention days"
                min="1"
                max="3650"
                required
              />
              <.input
                field={@project_form[:retention_event_limit]}
                type="number"
                label="Event retention cap"
                min="1"
                max="10000000"
                required
              />
              <button
                id="save-project-cost-controls-button"
                type="submit"
                class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md sm:col-span-2"
              >
                <.icon name="hero-circle-stack" class="size-4" /> Save cost controls
              </button>
            </.form>
          </section>

          <aside
            id="project-drop-rule-form-panel"
            class="h-fit rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm"
          >
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              New drop rule
            </h2>
            <.form
              for={@drop_form}
              id="drop-rule-form"
              phx-change="validate_drop_rule"
              phx-submit="save_drop_rule"
              class="mt-5 space-y-4"
            >
              <.input field={@drop_form[:name]} type="text" label="Name" required />
              <.input field={@drop_form[:enabled]} type="checkbox" label="Enabled" />
              <.input
                field={@drop_form[:match_field]}
                type="select"
                label="Field"
                options={@drop_rule_field_options}
                required
              />
              <.input
                field={@drop_form[:match_type]}
                type="select"
                label="Match"
                options={@drop_rule_type_options}
                required
              />
              <.input field={@drop_form[:match_value]} type="text" label="Value" required />
              <button
                id="save-drop-rule-button"
                type="submit"
                class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
              >
                <.icon name="hero-no-symbol" class="size-4" /> Create drop rule
              </button>
            </.form>
          </aside>
        </section>

        <section class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm">
          <div class="border-b border-base-300 px-5 py-4">
            <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
              Drop rules
            </h2>
          </div>
          <div id="drop-rules" phx-update="stream" class="divide-y divide-base-300">
            <div id="drop-rules-empty-state" class="hidden px-5 py-10 text-center only:block">
              <p class="font-semibold text-base-content">No drop rules yet</p>
              <p class="mt-1 text-sm text-base-content/60">
                Drop noisy classes before they consume storage.
              </p>
            </div>
            <article
              :for={{id, drop_rule} <- @streams.drop_rules}
              id={id}
              class="grid gap-4 px-5 py-4 md:grid-cols-[minmax(0,1fr)_12rem]"
            >
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <p class="font-semibold text-base-content">{drop_rule.name}</p>
                  <span class={[
                    "rounded border px-2 py-0.5 text-xs font-semibold",
                    drop_rule.enabled && "border-success/20 bg-success/10 text-success",
                    !drop_rule.enabled && "border-base-300 bg-base-200 text-base-content/50"
                  ]}>
                    {if(drop_rule.enabled, do: "enabled", else: "disabled")}
                  </span>
                </div>
                <p class="mt-2 font-mono text-xs text-base-content/60">
                  {drop_rule.match_field} {drop_rule.match_type} "{drop_rule.match_value}"
                </p>
              </div>
              <div class="flex flex-wrap gap-2 md:justify-end">
                <button
                  id={"toggle-drop-rule-#{drop_rule.id}"}
                  type="button"
                  phx-click="toggle_drop_rule"
                  phx-value-id={drop_rule.id}
                  class="inline-flex items-center gap-1 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
                >
                  <.icon
                    name={if(drop_rule.enabled, do: "hero-pause", else: "hero-play")}
                    class="size-4"
                  /> {if(drop_rule.enabled, do: "Disable", else: "Enable")}
                </button>
                <button
                  id={"delete-drop-rule-#{drop_rule.id}"}
                  type="button"
                  phx-click="delete_drop_rule"
                  phx-value-id={drop_rule.id}
                  data-confirm="Delete this drop rule?"
                  class="inline-flex items-center gap-1 rounded-lg border border-error/20 px-3 py-2 text-sm font-semibold text-error transition hover:bg-error/10"
                >
                  <.icon name="hero-trash" class="size-4" /> Delete
                </button>
              </div>
            </article>
          </div>
        </section>

        <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_24rem]">
          <section id="project-alert-settings" class="space-y-6">
            <section class="overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-sm">
              <div class="border-b border-base-300 px-5 py-4">
                <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
                  Alert rules
                </h2>
              </div>

              <div id="alert-rules" phx-update="stream" class="divide-y divide-base-300">
                <div id="alert-rules-empty-state" class="hidden px-5 py-12 text-center only:block">
                  <div class="mx-auto max-w-sm">
                    <div class="mx-auto flex size-12 items-center justify-center rounded-full bg-orange-100 text-orange-700">
                      <.icon name="hero-bell-alert" class="size-6" />
                    </div>
                    <p class="mt-4 font-semibold text-base-content">No alert rules yet</p>
                    <p class="mt-1 text-sm leading-6 text-base-content/60">
                      Create a rule to notify your team when this project receives new or regressed issues.
                    </p>
                  </div>
                </div>

                <article
                  :for={{id, rule} <- @streams.alert_rules}
                  id={id}
                  class="grid gap-4 px-5 py-5 lg:grid-cols-[minmax(0,1fr)_12rem]"
                >
                  <div class="min-w-0">
                    <div class="flex flex-wrap items-center gap-2">
                      <p class="font-semibold text-base-content">{rule.name}</p>
                      <span class={[
                        "rounded border px-2 py-0.5 text-xs font-semibold",
                        rule.enabled && "border-success/20 bg-success/10 text-success",
                        !rule.enabled && "border-base-300 bg-base-200 text-base-content/50"
                      ]}>
                        {if(rule.enabled, do: "enabled", else: "disabled")}
                      </span>
                    </div>

                    <dl class="mt-3 grid gap-2 text-sm sm:grid-cols-2">
                      <.rule_kv label="Trigger" value={trigger_label(rule.notify_on)} />
                      <.rule_kv label="Channel" value={channel_label(rule.channel)} />
                      <.rule_kv label="Target" value={rule.target} />
                      <.rule_kv label="Cooldown" value={"#{rule.cooldown_seconds}s"} />
                      <.rule_kv label="Threshold" value={Integer.to_string(rule.threshold_count)} />
                    </dl>
                  </div>

                  <div class="flex flex-wrap items-start gap-2 lg:justify-end">
                    <button
                      id={"toggle-alert-rule-#{rule.id}"}
                      type="button"
                      phx-click="toggle"
                      phx-value-id={rule.id}
                      class="inline-flex items-center gap-1 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
                    >
                      <.icon
                        name={if(rule.enabled, do: "hero-pause", else: "hero-play")}
                        class="size-4"
                      /> {if(rule.enabled, do: "Disable", else: "Enable")}
                    </button>
                    <button
                      id={"edit-alert-rule-#{rule.id}"}
                      type="button"
                      phx-click="edit"
                      phx-value-id={rule.id}
                      class="inline-flex items-center gap-1 rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold text-base-content/70 transition hover:bg-base-200 hover:text-base-content"
                    >
                      <.icon name="hero-pencil-square" class="size-4" /> Edit
                    </button>
                    <button
                      id={"delete-alert-rule-#{rule.id}"}
                      type="button"
                      phx-click="delete"
                      phx-value-id={rule.id}
                      data-confirm="Delete this alert rule?"
                      class="inline-flex items-center gap-1 rounded-lg border border-error/20 px-3 py-2 text-sm font-semibold text-error transition hover:bg-error/10"
                    >
                      <.icon name="hero-trash" class="size-4" /> Delete
                    </button>
                  </div>
                </article>
              </div>
            </section>
          </section>

          <aside class="h-fit rounded-lg border border-base-300 bg-base-100 p-5 shadow-sm">
            <div class="flex items-start justify-between gap-3">
              <div>
                <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/60">
                  {if(@editing_rule, do: "Edit rule", else: "New rule")}
                </h2>
                <p class="mt-1 text-sm leading-6 text-base-content/60">
                  Alert delivery is deduplicated per issue and rule by cooldown.
                </p>
              </div>
              <button
                :if={@editing_rule}
                id="cancel-alert-rule-edit"
                type="button"
                phx-click="cancel_edit"
                class="rounded-lg px-2 py-1 text-sm font-semibold text-base-content/60 transition hover:bg-base-200 hover:text-base-content"
              >
                Cancel
              </button>
            </div>

            <.form
              for={@form}
              id="alert-rule-form"
              phx-change="validate"
              phx-submit="save"
              class="mt-5 space-y-4"
            >
              <.input field={@form[:name]} type="text" label="Name" required />
              <.input
                field={@form[:enabled]}
                type="checkbox"
                label="Enabled"
              />
              <.input
                field={@form[:notify_on]}
                type="select"
                label="Trigger"
                options={@notify_on_options}
                required
              />
              <.input
                field={@form[:channel]}
                type="select"
                label="Channel"
                options={@channel_options}
                required
              />
              <.input
                field={@form[:target]}
                type="text"
                label="Target"
                placeholder="alerts@example.com or https://hooks.example.com/..."
                required
              />
              <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-1">
                <.input
                  field={@form[:threshold_count]}
                  type="number"
                  label="Threshold"
                  min="1"
                  max="1000000"
                  required
                />
                <.input
                  field={@form[:cooldown_seconds]}
                  type="number"
                  label="Cooldown seconds"
                  min="0"
                  max="86400"
                  required
                />
              </div>

              <button
                id="save-alert-rule-button"
                type="submit"
                class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
              >
                <.icon name="hero-bell-alert" class="size-4" />
                {if(@editing_rule, do: "Save rule", else: "Create rule")}
              </button>
            </.form>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp rule_kv(assigns) do
    ~H"""
    <div class="min-w-0">
      <dt class="text-base-content/50">{@label}</dt>
      <dd class="mt-0.5 break-words font-medium text-base-content">{@value}</dd>
    </div>
    """
  end

  defp create_rule(socket, params) do
    case Alerts.create_alert_rule(socket.assigns.project, params) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert rule created.")
         |> assign_form(new_rule_changeset(socket.assigns.project))
         |> stream_insert(:alert_rules, rule, at: 0)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  defp update_rule(socket, rule, params) do
    case Alerts.update_alert_rule(rule, params) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert rule updated.")
         |> assign(:editing_rule, nil)
         |> assign_form(new_rule_changeset(socket.assigns.project))
         |> stream_insert(:alert_rules, rule)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :update))}
    end
  end

  defp maybe_reset_deleted_editor(socket, rule) do
    case socket.assigns.editing_rule do
      %{id: id} when id == rule.id ->
        socket
        |> assign(:editing_rule, nil)
        |> assign_form(new_rule_changeset(socket.assigns.project))

      _editing_rule ->
        socket
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp assign_project_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :project_form, to_form(changeset))
  end

  defp assign_drop_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :drop_form, to_form(changeset))
  end

  defp form_rule(%{editing_rule: %AlertRule{} = rule}), do: rule
  defp form_rule(_assigns), do: %AlertRule{}

  defp rule_changeset(%AlertRule{id: nil} = rule, project, params) do
    params =
      params
      |> Map.new()
      |> Map.put("project_id", project.id)

    Alerts.change_alert_rule(rule, params)
  end

  defp rule_changeset(%AlertRule{} = rule, _project, params) do
    Alerts.change_alert_rule(rule, Map.put(Map.new(params), "project_id", rule.project_id))
  end

  defp new_rule_changeset(project) do
    Alerts.change_alert_rule(%AlertRule{}, %{
      "project_id" => project.id,
      "enabled" => true,
      "notify_on" => "new_issue",
      "channel" => "email",
      "threshold_count" => 1,
      "cooldown_seconds" => 900
    })
  end

  defp toggle_attrs(rule) do
    %{
      "name" => rule.name,
      "enabled" => !rule.enabled,
      "notify_on" => rule.notify_on,
      "channel" => rule.channel,
      "target" => rule.target,
      "threshold_count" => rule.threshold_count,
      "cooldown_seconds" => rule.cooldown_seconds
    }
  end

  defp drop_rule_changeset(%ProjectDropRule{} = drop_rule, project, params) do
    params =
      params
      |> Map.new()
      |> Map.put("project_id", project.id)

    Retention.change_drop_rule(drop_rule, params)
  end

  defp new_drop_rule_changeset(project) do
    Retention.change_drop_rule(%ProjectDropRule{}, %{
      "project_id" => project.id,
      "enabled" => true,
      "match_field" => "exception_type",
      "match_type" => "contains"
    })
  end

  defp drop_rule_toggle_attrs(drop_rule) do
    %{
      "name" => drop_rule.name,
      "enabled" => !drop_rule.enabled,
      "match_field" => drop_rule.match_field,
      "match_type" => drop_rule.match_type,
      "match_value" => drop_rule.match_value
    }
  end

  defp trigger_label("new_issue"), do: "New issues"
  defp trigger_label("regression"), do: "Regressions"
  defp trigger_label("frequency"), do: "Frequency alerts"
  defp trigger_label(value), do: value

  defp channel_label("email"), do: "Email"
  defp channel_label("webhook"), do: "Webhook"
  defp channel_label("slack"), do: "Slack webhook"
  defp channel_label(value), do: value
end
