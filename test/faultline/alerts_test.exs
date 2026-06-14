defmodule Faultline.AlertsTest do
  use Faultline.DataCase, async: false

  import Swoosh.TestAssertions

  alias Faultline.Events
  alias Faultline.Alerts
  alias Faultline.Alerts.AlertRule
  alias Faultline.Ingest.RawEvent
  alias Faultline.Projects
  alias Faultline.Repo

  @fixtures Path.expand("../fixtures/sentry_events", __DIR__)

  defmodule HTTPClient do
    def post(url, opts) do
      send(self(), {:alert_http_post, url, opts})
      {:ok, %{status: 202, body: %{"ok" => true}}}
    end
  end

  setup do
    original_config = Application.get_env(:faultline, Faultline.Alerts.Notifier, [])
    Application.put_env(:faultline, Faultline.Alerts.Notifier, http_client: HTTPClient)

    on_exit(fn ->
      Application.put_env(:faultline, Faultline.Alerts.Notifier, original_config)
    end)
  end

  describe "alert rules" do
    test "create_alert_rule/2 creates a project-scoped rule" do
      project = project_fixture()

      assert {:ok, rule} =
               Alerts.create_alert_rule(project, %{
                 "name" => "New issue email",
                 "notify_on" => "new_issue",
                 "channel" => "email",
                 "target" => "alerts@example.com",
                 "threshold_count" => "1",
                 "cooldown_seconds" => "900"
               })

      assert rule.project_id == project.id
      assert rule.enabled
      assert rule.name == "New issue email"
      assert rule.notify_on == "new_issue"
      assert rule.channel == "email"
      assert rule.target == "alerts@example.com"
      assert rule.threshold_count == 1
      assert rule.cooldown_seconds == 900
    end

    test "create_alert_rule/2 validates target by channel" do
      project = project_fixture()

      assert {:error, email_changeset} =
               Alerts.create_alert_rule(project, %{
                 "name" => "Broken email",
                 "notify_on" => "new_issue",
                 "channel" => "email",
                 "target" => "not-an-email",
                 "threshold_count" => "1",
                 "cooldown_seconds" => "900"
               })

      assert "must be an email" in errors_on(email_changeset).target

      assert {:error, webhook_changeset} =
               Alerts.create_alert_rule(project, %{
                 "name" => "Broken webhook",
                 "notify_on" => "regression",
                 "channel" => "webhook",
                 "target" => "ftp://example.com/hook",
                 "threshold_count" => "1",
                 "cooldown_seconds" => "900"
               })

      assert "must be an http or https URL" in errors_on(webhook_changeset).target
    end

    test "list_project_alert_rules/1 returns only rules for the project" do
      project = project_fixture()
      other_project = project_fixture()

      assert {:ok, first} =
               Alerts.create_alert_rule(project, valid_rule_attrs(%{"name" => "First"}))

      assert {:ok, second} =
               Alerts.create_alert_rule(project, valid_rule_attrs(%{"name" => "Second"}))

      assert {:ok, _other} =
               Alerts.create_alert_rule(other_project, valid_rule_attrs(%{"name" => "Other"}))

      assert [^second, ^first] = Alerts.list_project_alert_rules(project.id)
    end

    test "list_enabled_alert_rules/2 filters disabled rules and trigger type" do
      project = project_fixture()

      assert {:ok, enabled} =
               Alerts.create_alert_rule(project, valid_rule_attrs(%{"name" => "Enabled"}))

      assert {:ok, _disabled} =
               Alerts.create_alert_rule(
                 project,
                 valid_rule_attrs(%{"name" => "Disabled", "enabled" => false})
               )

      assert {:ok, _regression} =
               Alerts.create_alert_rule(
                 project,
                 valid_rule_attrs(%{"name" => "Regression", "notify_on" => "regression"})
               )

      assert [^enabled] = Alerts.list_enabled_alert_rules(project.id, "new_issue")
    end

    test "update_alert_rule/2 and delete_alert_rule/1 manage existing rules" do
      project = project_fixture()

      assert {:ok, rule} =
               Alerts.create_alert_rule(project, valid_rule_attrs(%{"name" => "Original"}))

      assert {:ok, updated} =
               Alerts.update_alert_rule(rule, %{
                 "name" => "Updated",
                 "enabled" => false,
                 "notify_on" => "frequency",
                 "channel" => "slack",
                 "target" => "https://hooks.example.com/slack",
                 "threshold_count" => "25",
                 "cooldown_seconds" => "1800",
                 "project_id" => project.id
               })

      assert updated.name == "Updated"
      refute updated.enabled
      assert updated.notify_on == "frequency"
      assert updated.channel == "slack"
      assert updated.target == "https://hooks.example.com/slack"
      assert updated.threshold_count == 25
      assert updated.cooldown_seconds == 1800

      assert {:ok, %AlertRule{}} = Alerts.delete_alert_rule(updated)
      assert Alerts.list_project_alert_rules(project.id) == []
    end

    test "create_alert_rule/2 keeps rule names unique per project" do
      project = project_fixture()

      assert {:ok, _rule} =
               Alerts.create_alert_rule(project, valid_rule_attrs(%{"name" => "Duplicate"}))

      assert {:error, changeset} =
               Alerts.create_alert_rule(project, valid_rule_attrs(%{"name" => "Duplicate"}))

      assert "has already been taken" in errors_on(changeset).name
    end

    test "dispatch_issue_alerts/4 sends email notifications" do
      project = project_fixture()
      event = event_fixture(project)
      issue = Repo.get!(Faultline.Issues.Issue, event.issue_id)

      assert {:ok, _rule} =
               Alerts.create_alert_rule(
                 project,
                 valid_rule_attrs(%{
                   "name" => "Email",
                   "channel" => "email",
                   "target" => "alerts@example.com"
                 })
               )

      assert [%{status: "delivered", channel: "email"}] =
               Alerts.dispatch_issue_alerts(project.id, issue, event, "new_issue")

      assert_email_sent(
        to: {"", "alerts@example.com"},
        subject: "[Faultline] New issue: TypeError: Cannot read properties of undefined"
      )
    end

    test "dispatch_issue_alerts/4 sends webhook and slack notifications with Req-compatible client" do
      project = project_fixture()
      event = event_fixture(project)
      issue = Repo.get!(Faultline.Issues.Issue, event.issue_id)

      assert {:ok, _webhook} =
               Alerts.create_alert_rule(
                 project,
                 valid_rule_attrs(%{
                   "name" => "Webhook",
                   "channel" => "webhook",
                   "target" => "https://example.com/webhook"
                 })
               )

      assert {:ok, _slack} =
               Alerts.create_alert_rule(
                 project,
                 valid_rule_attrs(%{
                   "name" => "Slack",
                   "channel" => "slack",
                   "target" => "https://hooks.example.com/slack"
                 })
               )

      assert [%{status: "delivered"}, %{status: "delivered"}] =
               Alerts.dispatch_issue_alerts(project.id, issue, event, "new_issue")

      assert_receive {:alert_http_post, "https://example.com/webhook", webhook_opts}
      assert webhook_opts[:json].trigger == "new_issue"
      assert webhook_opts[:json].issue.id == issue.id

      assert_receive {:alert_http_post, "https://hooks.example.com/slack", slack_opts}
      assert slack_opts[:json].text =~ "New issue"
      assert slack_opts[:json].text =~ issue.title
    end

    test "dispatch_issue_alerts/4 suppresses duplicate issue notifications within cooldown" do
      project = project_fixture()
      event = event_fixture(project)
      issue = Repo.get!(Faultline.Issues.Issue, event.issue_id)

      assert {:ok, _rule} =
               Alerts.create_alert_rule(
                 project,
                 valid_rule_attrs(%{
                   "name" => "Dedupe",
                   "target" => "https://example.com/webhook",
                   "cooldown_seconds" => "900"
                 })
               )

      assert [%{status: "delivered"}] =
               Alerts.dispatch_issue_alerts(project.id, issue, event, "new_issue")

      assert_receive {:alert_http_post, "https://example.com/webhook", _opts}

      assert [%{status: "suppressed"}] =
               Alerts.dispatch_issue_alerts(project.id, issue, event, "new_issue")

      refute_receive {:alert_http_post, "https://example.com/webhook", _opts}
    end

    test "grouping a new issue dispatches new_issue alerts" do
      project = project_fixture()

      assert {:ok, _rule} =
               Alerts.create_alert_rule(project, valid_rule_attrs(%{"name" => "New issue hook"}))

      _event = event_fixture(project)

      assert_receive {:alert_http_post, "https://example.com/webhook", opts}
      assert opts[:json].trigger == "new_issue"
      assert opts[:json].project.id == project.id
    end

    test "grouping a resolved issue dispatches regression alerts" do
      project = project_fixture()

      assert {:ok, _rule} =
               Alerts.create_alert_rule(
                 project,
                 valid_rule_attrs(%{"name" => "Regression hook", "notify_on" => "regression"})
               )

      first = event_fixture(project)
      issue = Repo.get!(Faultline.Issues.Issue, first.issue_id)
      assert {:ok, _resolved_issue} = Faultline.Issues.update_issue_status(issue, "resolved")

      _second =
        event_fixture(project, %{
          "event_id" => "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "timestamp" => "2026-06-14T15:05:00Z"
        })

      assert_receive {:alert_http_post, "https://example.com/webhook", opts}
      assert opts[:json].trigger == "regression"
      assert opts[:json].issue.id == issue.id
    end
  end

  defp valid_rule_attrs(attrs) do
    Map.merge(
      %{
        "name" => "New issues",
        "enabled" => true,
        "notify_on" => "new_issue",
        "channel" => "webhook",
        "target" => "https://example.com/webhook",
        "threshold_count" => "1",
        "cooldown_seconds" => "900"
      },
      attrs
    )
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

  defp event_fixture(project, overrides \\ %{}) do
    payload =
      "javascript.json"
      |> fixture_payload()
      |> Map.merge(overrides)

    raw_event =
      %RawEvent{}
      |> RawEvent.changeset(%{
        project_id: project.id,
        event_id: payload["event_id"],
        source: "store",
        payload_type: "event",
        payload: payload,
        auth: %{"public_key" => project.public_key},
        received_at: ~U[2026-06-14 16:00:00.000000Z]
      })
      |> Repo.insert!()

    assert {:ok, event} = Events.normalize_raw_event(raw_event)
    event
  end

  defp fixture_payload(filename) do
    @fixtures
    |> Path.join(filename)
    |> File.read!()
    |> Jason.decode!()
  end
end
