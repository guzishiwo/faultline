defmodule Faultline.Issues do
  @moduledoc """
  Issue grouping and lifecycle.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Faultline.Events.Event
  alias Faultline.Issues.Grouping
  alias Faultline.Issues.Issue
  alias Faultline.Repo

  @reopen_statuses ~w(resolved)

  @doc """
  Groups an event into an issue and links the event to it.
  """
  def group_event(%Event{} = event) do
    fingerprint = Grouping.fingerprint(event)

    Multi.new()
    |> Multi.run(:issue, fn repo, _changes ->
      issue =
        repo.get_by(Issue, project_id: event.project_id, fingerprint: fingerprint) ||
          create_issue!(repo, event, fingerprint)

      {:ok, issue}
    end)
    |> Multi.run(:updated_issue, fn repo, %{issue: issue} ->
      issue
      |> update_issue_attrs(event)
      |> then(&repo.update(Issue.changeset(issue, &1)))
    end)
    |> Multi.update(:event, fn %{updated_issue: issue} ->
      Event.issue_changeset(event, issue)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{updated_issue: issue, event: event}} -> {:ok, issue, event}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  @doc """
  Updates an issue status.
  """
  def update_issue_status(%Issue{} = issue, status) do
    issue
    |> Issue.status_changeset(status)
    |> Repo.update()
  end

  def list_project_issues(project_id) do
    Issue
    |> where([issue], issue.project_id == ^project_id)
    |> order_by([issue], desc: issue.last_seen_at, desc: issue.id)
    |> Repo.all()
  end

  defp create_issue!(repo, event, fingerprint) do
    %Issue{}
    |> Issue.changeset(%{
      project_id: event.project_id,
      fingerprint: fingerprint,
      title: Grouping.title(event),
      status: "unresolved",
      first_seen_at: event.occurred_at,
      last_seen_at: event.occurred_at,
      event_count: 0,
      affected_user_count: 0
    })
    |> repo.insert!()
  end

  defp update_issue_attrs(issue, event) do
    %{
      title: issue.title,
      status: next_status(issue.status),
      first_seen_at: min_datetime(issue.first_seen_at, event.occurred_at),
      last_seen_at: max_datetime(issue.last_seen_at, event.occurred_at),
      event_count: issue.event_count + 1,
      affected_user_count: affected_user_count(issue, event)
    }
  end

  defp next_status(status) when status in @reopen_statuses, do: "unresolved"
  defp next_status(status), do: status

  defp affected_user_count(issue, %Event{user_identifier: nil}), do: issue.affected_user_count
  defp affected_user_count(issue, %Event{user_identifier: ""}), do: issue.affected_user_count

  defp affected_user_count(issue, event) do
    user_seen? =
      Event
      |> where([existing], existing.issue_id == ^issue.id)
      |> where([existing], existing.user_identifier == ^event.user_identifier)
      |> Repo.exists?()

    if user_seen? do
      issue.affected_user_count
    else
      issue.affected_user_count + 1
    end
  end

  defp min_datetime(first, second) do
    if DateTime.compare(first, second) == :gt, do: second, else: first
  end

  defp max_datetime(first, second) do
    if DateTime.compare(first, second) == :lt, do: second, else: first
  end
end
