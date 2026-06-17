defmodule FaultlineWeb.ProjectSettingsLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Faultline.Alerts
  alias Faultline.Projects
  alias Faultline.Retention

  setup :register_and_log_in_user

  test "defaults to rules tab and manages rules", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/settings")

    assert has_element?(view, "#project-settings-page")
    assert has_element?(view, "#project-rules-tab")
    assert has_element?(view, "#settings-tab-rules[aria-current='page']")
    assert has_element?(view, "#settings-tab-ingest")
    assert has_element?(view, "#settings-tab-sdk")
    assert has_element?(view, "#rules-workspace-header")
    assert has_element?(view, "#new-drop-rule-button")
    assert has_element?(view, "#new-alert-rule-button")
    assert has_element?(view, "#rule-builder-empty-state")
    assert has_element?(view, "#drop-rules")
    assert has_element?(view, "#project-usage-link")
    assert has_element?(view, "#project-alert-settings + #project-drop-settings")
    assert has_element?(view, "#alert-rules")
    assert has_element?(view, "#alert-rules-empty-state")
    refute has_element?(view, "#drop-rule-form")
    refute has_element?(view, "#alert-rule-form")
    refute has_element?(view, "#project-cost-controls-form")
    refute has_element?(view, "#project-dsn")

    view
    |> element("#new-drop-rule-button")
    |> render_click()

    assert has_element?(view, "#drop-rule-form")
    refute has_element?(view, "#alert-rule-form")

    view
    |> form("#drop-rule-form",
      project_drop_rule: %{
        name: "Ignore noisy timeout",
        enabled: "true",
        match_field: "exception_type",
        match_type: "contains",
        match_value: "TimeoutError"
      }
    )
    |> render_submit()

    [drop_rule] = Retention.list_project_drop_rules(project.id)
    assert has_element?(view, "#drop-rules-#{drop_rule.id}", "Ignore noisy timeout")
    assert has_element?(view, "#rule-builder-empty-state")

    view
    |> element("#toggle-drop-rule-#{drop_rule.id}")
    |> render_click()

    drop_rule = Retention.get_project_drop_rule!(project.id, drop_rule.id)
    refute drop_rule.enabled
    assert has_element?(view, "#drop-rules-#{drop_rule.id}", "disabled")

    view
    |> element("#delete-drop-rule-#{drop_rule.id}")
    |> render_click()

    assert Retention.list_project_drop_rules(project.id) == []
    refute has_element?(view, "#drop-rules-#{drop_rule.id}")

    view
    |> element("#new-alert-rule-button")
    |> render_click()

    assert has_element?(view, "#alert-rule-form")
    refute has_element?(view, "#drop-rule-form")

    view
    |> form("#alert-rule-form",
      alert_rule: %{
        name: "New issue email",
        enabled: "true",
        notify_on: "new_issue",
        channel: "email",
        target: "alerts@example.com",
        threshold_count: "1",
        cooldown_seconds: "900"
      }
    )
    |> render_submit()

    [rule] = Alerts.list_project_alert_rules(project.id)

    assert has_element?(view, "#alert-rules-#{rule.id}")
    assert has_element?(view, "#alert-rules-#{rule.id}", "New issue email")
    assert has_element?(view, "#alert-rules-#{rule.id}", "Email")
    assert has_element?(view, "#rule-builder-empty-state")

    view
    |> element("#edit-alert-rule-#{rule.id}")
    |> render_click()

    assert has_element?(view, "#alert-rule-form")

    view
    |> form("#alert-rule-form",
      alert_rule: %{
        name: "Regression webhook",
        enabled: "true",
        notify_on: "regression",
        channel: "webhook",
        target: "https://example.com/hook",
        threshold_count: "5",
        cooldown_seconds: "1200"
      }
    )
    |> render_submit()

    rule = Alerts.get_project_alert_rule!(project.id, rule.id)

    assert rule.name == "Regression webhook"
    assert rule.notify_on == "regression"
    assert rule.channel == "webhook"
    assert rule.target == "https://example.com/hook"
    assert rule.threshold_count == 5
    assert rule.cooldown_seconds == 1200

    assert has_element?(view, "#alert-rules-#{rule.id}", "Regression webhook")
    assert has_element?(view, "#alert-rules-#{rule.id}", "Webhook")
    assert has_element?(view, "#rule-builder-empty-state")

    view
    |> element("#toggle-alert-rule-#{rule.id}")
    |> render_click()

    rule = Alerts.get_project_alert_rule!(project.id, rule.id)
    refute rule.enabled
    assert has_element?(view, "#alert-rules-#{rule.id}", "disabled")

    view
    |> element("#delete-alert-rule-#{rule.id}")
    |> render_click()

    assert Alerts.list_project_alert_rules(project.id) == []
    refute has_element?(view, "#alert-rules-#{rule.id}")
  end

  test "falls back to rules tab for invalid tab params", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/settings?tab=unknown")

    assert has_element?(view, "#project-rules-tab")
    assert has_element?(view, "#settings-tab-rules[aria-current='page']")
  end

  test "updates ingest and retention settings from ingest tab", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/settings?tab=ingest")

    assert has_element?(view, "#project-ingest-tab")
    assert has_element?(view, "#settings-tab-ingest[aria-current='page']")
    assert has_element?(view, "#project-ingest-settings")
    assert has_element?(view, "#project-cost-controls-form")
    refute has_element?(view, "#drop-rule-form")

    view
    |> form("#project-cost-controls-form",
      project: %{
        rate_limit_max_events: "50",
        rate_limit_window_seconds: "10",
        retention_days: "14",
        retention_event_limit: "500"
      }
    )
    |> render_submit()

    project = Projects.get_project!(project.id)
    assert project.rate_limit_max_events == 50
    assert project.rate_limit_window_seconds == 10
    assert project.retention_days == 14
    assert project.retention_event_limit == 500
  end

  test "shows sdk setup tab with dsn copy action", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/settings?tab=sdk")

    assert has_element?(view, "#project-sdk-tab")
    assert has_element?(view, "#settings-tab-sdk[aria-current='page']")
    assert has_element?(view, "#project-sdk-settings")
    assert has_element?(view, "#project-sdk-domain-card")
    assert has_element?(view, "#project-sdk-dsn-origin", "https://errors.example.com")
    assert has_element?(view, "#project-dsn", project.dsn)

    assert has_element?(
             view,
             "#copy-project-dsn-button[phx-hook='ClipboardCopy'][data-copy='#{project.dsn}']"
           )

    refute has_element?(view, "#drop-rule-form")
  end

  test "shows validation errors for invalid alert targets", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/settings")

    view
    |> element("#new-alert-rule-button")
    |> render_click()

    view
    |> form("#alert-rule-form",
      alert_rule: %{
        name: "Broken",
        enabled: "true",
        notify_on: "new_issue",
        channel: "email",
        target: "not-an-email",
        threshold_count: "1",
        cooldown_seconds: "900"
      }
    )
    |> render_submit()

    assert has_element?(view, "#alert-rule-form", "must be an email")
  end

  test "project list links to project settings", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "#project-settings-link-#{project.id}")
  end

  test "shows project usage page", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/usage")

    assert has_element?(view, "#project-usage-page")
    assert has_element?(view, "#usage-events", "0")
    assert has_element?(view, "#usage-raw-events", "0")
    assert has_element?(view, "#usage-issues", "0")
    assert has_element?(view, "#usage-retention", "#{project.retention_days} days")
  end

  defp project_fixture do
    assert {:ok, project} =
             Projects.create_project(%{"name" => unique_project_name()},
               dsn_base_url: "https://errors.example.com"
             )

    project
  end

  defp unique_project_name do
    "Project #{System.unique_integer([:positive])}"
  end
end
