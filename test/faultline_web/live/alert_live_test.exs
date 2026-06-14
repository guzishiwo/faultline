defmodule FaultlineWeb.AlertLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Faultline.Alerts
  alias Faultline.Projects

  setup :register_and_log_in_user

  test "creates, edits, toggles, and deletes project alert rules", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/alerts")

    assert has_element?(view, "#alert-rules")
    assert has_element?(view, "#alert-rule-form")
    assert has_element?(view, "#alert-rules-empty-state")

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

    view
    |> element("#edit-alert-rule-#{rule.id}")
    |> render_click()

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

  test "shows validation errors for invalid alert targets", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/alerts")

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

  test "project list links to alert settings", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "#project-alerts-link-#{project.id}")
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
