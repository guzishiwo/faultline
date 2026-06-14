defmodule Faultline.Alerts do
  @moduledoc """
  Project alert rule configuration.
  """

  import Ecto.Query, warn: false

  alias Faultline.Alerts.AlertDelivery
  alias Faultline.Alerts.AlertRule
  alias Faultline.Alerts.Notifier
  alias Faultline.Events.Event
  alias Faultline.Issues.Issue
  alias Faultline.Projects.Project
  alias Faultline.Repo

  @doc """
  Lists alert rules for a project, newest first.
  """
  def list_project_alert_rules(project_id) do
    AlertRule
    |> where([rule], rule.project_id == ^project_id)
    |> order_by([rule], desc: rule.inserted_at, desc: rule.id)
    |> Repo.all()
  end

  @doc """
  Lists enabled alert rules for a project and trigger.
  """
  def list_enabled_alert_rules(project_id, notify_on) do
    AlertRule
    |> where([rule], rule.project_id == ^project_id)
    |> where([rule], rule.enabled)
    |> where([rule], rule.notify_on == ^notify_on)
    |> order_by([rule], asc: rule.id)
    |> Repo.all()
  end

  @doc """
  Gets a single alert rule scoped to a project.
  """
  def get_project_alert_rule!(project_id, id) do
    Repo.get_by!(AlertRule, project_id: project_id, id: id)
  end

  @doc """
  Creates an alert rule for a project.
  """
  def create_alert_rule(%Project{} = project, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put("project_id", project.id)

    %AlertRule{}
    |> AlertRule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an alert rule.
  """
  def update_alert_rule(%AlertRule{} = alert_rule, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put("project_id", alert_rule.project_id)

    alert_rule
    |> AlertRule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an alert rule.
  """
  def delete_alert_rule(%AlertRule{} = alert_rule) do
    Repo.delete(alert_rule)
  end

  @doc """
  Returns an alert rule changeset for forms.
  """
  def change_alert_rule(%AlertRule{} = alert_rule, attrs \\ %{}) do
    AlertRule.changeset(alert_rule, attrs)
  end

  @doc """
  Dispatches alert notifications for an issue trigger.

  Delivery failures are recorded and returned, but they do not raise.
  """
  def dispatch_issue_alerts(project_id, %Issue{} = issue, %Event{} = event, trigger) do
    project = Repo.get!(Project, project_id)

    project.id
    |> list_enabled_alert_rules(trigger)
    |> Enum.map(&deliver_or_suppress(&1, project, issue, event, trigger))
  end

  defp deliver_or_suppress(%AlertRule{} = rule, project, issue, event, trigger) do
    now = DateTime.utc_now(:microsecond)

    if recently_delivered?(rule, issue, trigger, now) do
      record_delivery(rule, project, issue, trigger, "suppressed", now, nil)
    else
      case Notifier.deliver(rule, %{
             project: project,
             issue: issue,
             event: event,
             trigger: trigger
           }) do
        :ok ->
          record_delivery(rule, project, issue, trigger, "delivered", now, nil)

        {:error, reason} ->
          record_delivery(rule, project, issue, trigger, "failed", now, inspect(reason))
      end
    end
  end

  defp recently_delivered?(%AlertRule{cooldown_seconds: 0}, _issue, _trigger, _now), do: false

  defp recently_delivered?(%AlertRule{} = rule, %Issue{} = issue, trigger, now) do
    cutoff = DateTime.add(now, -rule.cooldown_seconds, :second)

    AlertDelivery
    |> where([delivery], delivery.alert_rule_id == ^rule.id)
    |> where([delivery], delivery.issue_id == ^issue.id)
    |> where([delivery], delivery.trigger == ^trigger)
    |> where([delivery], delivery.status == "delivered")
    |> where([delivery], delivery.delivered_at >= ^cutoff)
    |> Repo.exists?()
  end

  defp record_delivery(rule, project, issue, trigger, status, delivered_at, error) do
    %AlertDelivery{}
    |> AlertDelivery.changeset(%{
      trigger: trigger,
      channel: rule.channel,
      target: rule.target,
      status: status,
      delivered_at: delivered_at,
      error: error,
      alert_rule_id: rule.id,
      project_id: project.id,
      issue_id: issue.id
    })
    |> Repo.insert!()
  end
end
