defmodule FaultlineWeb.ProjectLive.Settings do
  use FaultlineWeb, :live_view

  import FaultlineWeb.ProjectLive.SettingsComponents

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

  @settings_tabs [
    %{id: "rules", label: "Rules", icon: "hero-bell-alert"},
    %{id: "ingest", label: "Ingest & retention", icon: "hero-bolt"},
    %{id: "sdk", label: "SDK setup", icon: "hero-key"}
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
     |> assign(:rule_builder, nil)
     |> assign(:active_tab, "rules")
     |> assign(:settings_tabs, @settings_tabs)
     |> assign(:alert_rule_count, length(rules))
     |> assign(:drop_rule_count, length(drop_rules))
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
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :active_tab, active_tab(params))}
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

    {:noreply,
     socket
     |> assign(:rule_builder, "drop")
     |> assign_drop_form(changeset)}
  end

  def handle_event("save_drop_rule", %{"project_drop_rule" => params}, socket) do
    case Retention.create_drop_rule(socket.assigns.project, params) do
      {:ok, drop_rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Drop rule created.")
         |> update(:drop_rule_count, &(&1 + 1))
         |> assign(:rule_builder, nil)
         |> assign_drop_form(new_drop_rule_changeset(socket.assigns.project))
         |> stream_insert(:drop_rules, drop_rule, at: 0)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:rule_builder, "drop")
         |> assign_drop_form(Map.put(changeset, :action, :insert))}
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

    {:noreply,
     socket
     |> update(:drop_rule_count, &max(&1 - 1, 0))
     |> stream_delete(:drop_rules, drop_rule)}
  end

  def handle_event("validate", %{"alert_rule" => params}, socket) do
    changeset =
      form_rule(socket.assigns)
      |> rule_changeset(socket.assigns.project, params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:rule_builder, "alert")
     |> assign_form(changeset)}
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
     |> assign(:rule_builder, "alert")
     |> assign_form(Alerts.change_alert_rule(rule))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_rule, nil)
     |> assign(:rule_builder, nil)
     |> assign_form(new_rule_changeset(socket.assigns.project))}
  end

  def handle_event("show_rule_builder", %{"type" => "alert"}, socket) do
    {:noreply,
     socket
     |> assign(:editing_rule, nil)
     |> assign(:rule_builder, "alert")
     |> assign_form(new_rule_changeset(socket.assigns.project))}
  end

  def handle_event("show_rule_builder", %{"type" => "drop"}, socket) do
    {:noreply,
     socket
     |> assign(:rule_builder, "drop")
     |> assign_drop_form(new_drop_rule_changeset(socket.assigns.project))}
  end

  def handle_event("clear_rule_builder", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_rule, nil)
     |> assign(:rule_builder, nil)
     |> assign_drop_form(new_drop_rule_changeset(socket.assigns.project))
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
     |> update(:alert_rule_count, &max(&1 - 1, 0))
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
              <p class="text-sm font-semibold uppercase tracking-[0.18em] text-primary">
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
              navigate={~p"/issues?project=#{@project.id}"}
              class="inline-flex w-fit items-center gap-2 rounded-lg bg-base-content px-4 py-2.5 text-sm font-semibold text-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
            >
              Open triage <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </header>

        <.settings_tabs project={@project} settings_tabs={@settings_tabs} active_tab={@active_tab} />

        <.sdk_tab :if={@active_tab == "sdk"} project={@project} current_scope={@current_scope} />

        <.ingest_tab
          :if={@active_tab == "ingest"}
          project={@project}
          project_form={@project_form}
        />

        <.rules_workspace
          :if={@active_tab == "rules"}
          alert_rule_count={@alert_rule_count}
          drop_rule_count={@drop_rule_count}
          alert_rules={@streams.alert_rules}
          drop_rules={@streams.drop_rules}
          rule_builder={@rule_builder}
          editing_rule={@editing_rule}
          form={@form}
          drop_form={@drop_form}
          notify_on_options={@notify_on_options}
          channel_options={@channel_options}
          drop_rule_field_options={@drop_rule_field_options}
          drop_rule_type_options={@drop_rule_type_options}
        />
      </div>
    </Layouts.app>
    """
  end

  defp create_rule(socket, params) do
    case Alerts.create_alert_rule(socket.assigns.project, params) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert rule created.")
         |> update(:alert_rule_count, &(&1 + 1))
         |> assign(:rule_builder, nil)
         |> assign_form(new_rule_changeset(socket.assigns.project))
         |> stream_insert(:alert_rules, rule, at: 0)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:rule_builder, "alert")
         |> assign_form(Map.put(changeset, :action, :insert))}
    end
  end

  defp update_rule(socket, rule, params) do
    case Alerts.update_alert_rule(rule, params) do
      {:ok, rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert rule updated.")
         |> assign(:editing_rule, nil)
         |> assign(:rule_builder, nil)
         |> assign_form(new_rule_changeset(socket.assigns.project))
         |> stream_insert(:alert_rules, rule)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:rule_builder, "alert")
         |> assign_form(Map.put(changeset, :action, :update))}
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

  defp active_tab(%{"tab" => tab}) when tab in ["rules", "ingest", "sdk"], do: tab
  defp active_tab(_params), do: "rules"
end
