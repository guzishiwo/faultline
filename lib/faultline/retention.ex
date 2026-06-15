defmodule Faultline.Retention do
  @moduledoc """
  Retention and cost controls for keeping a single-node deployment bounded.
  """

  import Ecto.Query, warn: false

  alias Faultline.Events.Event
  alias Faultline.Ingest.RawEvent
  alias Faultline.Issues.Issue
  alias Faultline.Projects
  alias Faultline.Projects.Project
  alias Faultline.Repo
  alias Faultline.Retention.ProjectDropRule

  def list_project_drop_rules(project_id) do
    ProjectDropRule
    |> where([rule], rule.project_id == ^project_id)
    |> order_by([rule], desc: rule.inserted_at, desc: rule.id)
    |> Repo.all()
  end

  def get_project_drop_rule!(project_id, id) do
    Repo.get_by!(ProjectDropRule, project_id: project_id, id: id)
  end

  def create_drop_rule(%Project{} = project, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put("project_id", project.id)

    %ProjectDropRule{}
    |> ProjectDropRule.changeset(attrs)
    |> Repo.insert()
  end

  def update_drop_rule(%ProjectDropRule{} = drop_rule, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put("project_id", drop_rule.project_id)

    drop_rule
    |> ProjectDropRule.changeset(attrs)
    |> Repo.update()
  end

  def delete_drop_rule(%ProjectDropRule{} = drop_rule), do: Repo.delete(drop_rule)

  def change_drop_rule(%ProjectDropRule{} = drop_rule, attrs \\ %{}) do
    ProjectDropRule.changeset(drop_rule, attrs)
  end

  def dropped_by_rule?(%Project{} = project, payload) when is_map(payload) do
    project.id
    |> enabled_drop_rules()
    |> Enum.any?(&matches_rule?(&1, payload))
  end

  def dropped_by_rule?(%Project{}, _payload), do: false

  def cleanup_all_projects(now \\ DateTime.utc_now()) do
    Projects.list_projects()
    |> Enum.reduce(%{projects: 0, raw_events_deleted: 0, issues_deleted: 0}, fn project, acc ->
      result = cleanup_project(project, now)

      %{
        projects: acc.projects + 1,
        raw_events_deleted: acc.raw_events_deleted + result.raw_events_deleted,
        issues_deleted: acc.issues_deleted + result.issues_deleted
      }
    end)
  end

  def cleanup_project(%Project{} = project, now \\ DateTime.utc_now()) do
    raw_event_ids =
      project
      |> raw_event_ids_past_retention(now)
      |> MapSet.union(raw_event_ids_past_cap(project))
      |> MapSet.to_list()

    issue_ids = issue_ids_for_raw_events(raw_event_ids)
    {raw_events_deleted, _} = delete_raw_events(raw_event_ids)
    issues_deleted = refresh_issues(issue_ids)

    %{raw_events_deleted: raw_events_deleted, issues_deleted: issues_deleted}
  end

  defp enabled_drop_rules(project_id) do
    ProjectDropRule
    |> where([rule], rule.project_id == ^project_id)
    |> where([rule], rule.enabled)
    |> Repo.all()
  end

  defp matches_rule?(%ProjectDropRule{} = rule, payload) do
    value =
      payload
      |> payload_field(rule.match_field)
      |> normalize_match_value()

    match_value = normalize_match_value(rule.match_value)

    case rule.match_type do
      "contains" -> value != "" and String.contains?(value, match_value)
      "equals" -> value == match_value
    end
  end

  defp payload_field(payload, "exception_type") do
    payload
    |> get_in(["exception", "values"])
    |> List.wrap()
    |> List.first()
    |> case do
      %{"type" => type} -> type
      _ -> nil
    end
  end

  defp payload_field(payload, field), do: Map.get(payload, field)

  defp normalize_match_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_match_value(_value), do: ""

  defp raw_event_ids_past_retention(project, now) do
    cutoff = DateTime.add(now, -project.retention_days, :day)

    RawEvent
    |> where([raw_event], raw_event.project_id == ^project.id)
    |> where([raw_event], raw_event.received_at < ^cutoff)
    |> select([raw_event], raw_event.id)
    |> Repo.all()
    |> MapSet.new()
  end

  defp raw_event_ids_past_cap(project) do
    kept_ids =
      RawEvent
      |> where([raw_event], raw_event.project_id == ^project.id)
      |> order_by([raw_event], desc: raw_event.received_at, desc: raw_event.id)
      |> limit(^project.retention_event_limit)
      |> select([raw_event], raw_event.id)

    RawEvent
    |> where([raw_event], raw_event.project_id == ^project.id)
    |> where([raw_event], raw_event.id not in subquery(kept_ids))
    |> select([raw_event], raw_event.id)
    |> Repo.all()
    |> MapSet.new()
  end

  defp issue_ids_for_raw_events([]), do: []

  defp issue_ids_for_raw_events(raw_event_ids) do
    Event
    |> where([event], event.raw_event_id in ^raw_event_ids)
    |> where([event], not is_nil(event.issue_id))
    |> distinct(true)
    |> select([event], event.issue_id)
    |> Repo.all()
  end

  defp delete_raw_events([]), do: {0, nil}

  defp delete_raw_events(raw_event_ids) do
    RawEvent
    |> where([raw_event], raw_event.id in ^raw_event_ids)
    |> Repo.delete_all()
  end

  defp refresh_issues(issue_ids) do
    issue_ids
    |> Enum.uniq()
    |> Enum.count(&refresh_issue/1)
  end

  defp refresh_issue(issue_id) do
    case issue_stats(issue_id) do
      %{event_count: 0} ->
        case Repo.get(Issue, issue_id) do
          nil ->
            false

          issue ->
            {:ok, _issue} = Repo.delete(issue)
            true
        end

      stats ->
        issue = Repo.get!(Issue, issue_id)

        {:ok, _issue} =
          issue
          |> Issue.changeset(%{
            project_id: issue.project_id,
            fingerprint: issue.fingerprint,
            title: issue.title,
            status: issue.status,
            first_seen_at: stats.first_seen_at,
            last_seen_at: stats.last_seen_at,
            event_count: stats.event_count,
            affected_user_count: stats.affected_user_count
          })
          |> Repo.update()

        false
    end
  end

  defp issue_stats(issue_id) do
    Event
    |> where([event], event.issue_id == ^issue_id)
    |> select([event], %{
      event_count: count(event.id),
      affected_user_count: count(event.user_identifier, :distinct),
      first_seen_at: min(event.occurred_at),
      last_seen_at: max(event.occurred_at)
    })
    |> Repo.one()
  end
end
