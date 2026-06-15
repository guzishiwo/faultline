defmodule Faultline.Issues do
  @moduledoc """
  Issue grouping and lifecycle.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Faultline.Alerts
  alias Faultline.Events.Event
  alias Faultline.Issues.Grouping
  alias Faultline.Issues.Issue
  alias Faultline.Repo

  @reopen_statuses ~w(resolved)
  @default_page_size 20

  @doc """
  Groups an event into an issue and links the event to it.
  """
  def group_event(%Event{} = event) do
    fingerprint = Grouping.fingerprint(event)

    Multi.new()
    |> Multi.run(:issue, fn repo, _changes ->
      case repo.get_by(Issue, project_id: event.project_id, fingerprint: fingerprint) do
        nil -> {:ok, {create_issue!(repo, event, fingerprint), true}}
        issue -> {:ok, {issue, false}}
      end
    end)
    |> Multi.run(:alert_trigger, fn _repo, %{issue: {issue, created?}} ->
      cond do
        created? -> {:ok, "new_issue"}
        issue.status in @reopen_statuses -> {:ok, "regression"}
        true -> {:ok, nil}
      end
    end)
    |> Multi.run(:issue_for_update, fn _repo, %{issue: {issue, _created?}} ->
      {:ok, issue}
    end)
    |> Multi.run(:updated_issue, fn repo, %{issue_for_update: issue} ->
      issue
      |> update_issue_attrs(event)
      |> then(&repo.update(Issue.changeset(issue, &1)))
    end)
    |> Multi.update(:event, fn %{updated_issue: issue} ->
      Event.issue_changeset(event, issue)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{updated_issue: issue, event: event, alert_trigger: alert_trigger}} ->
        broadcast_issue_change(issue)
        dispatch_alerts(event, issue, alert_trigger)
        {:ok, issue, event}

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  defp dispatch_alerts(_event, _issue, nil), do: :ok

  defp dispatch_alerts(event, issue, trigger) do
    _deliveries = Alerts.dispatch_issue_alerts(event.project_id, issue, event, trigger)
    :ok
  end

  @doc """
  Updates an issue status.
  """
  def update_issue_status(%Issue{} = issue, status) do
    issue
    |> Issue.status_changeset(status)
    |> Repo.update()
    |> case do
      {:ok, issue} ->
        broadcast_issue_change(issue)
        {:ok, issue}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def list_project_issues(project_id, opts \\ []) do
    opts
    |> Keyword.put(:project_id, project_id)
    |> issues_query()
    |> order_issues()
    |> Repo.all()
  end

  def paginate_project_issues(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_page_size)
    cursor = Keyword.get(opts, :after)

    issues =
      opts
      |> Keyword.put(:project_id, project_id)
      |> issues_query()
      |> after_cursor(cursor)
      |> order_issues()
      |> limit(^(limit + 1))
      |> Repo.all()

    {page, remaining} = Enum.split(issues, limit)

    %{
      issues: page,
      next_cursor: next_cursor(page, remaining)
    }
  end

  def list_issues(opts \\ []) do
    opts
    |> issues_query()
    |> order_issues()
    |> preload(:project)
    |> Repo.all()
  end

  def paginate_issues(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_page_size)
    cursor = Keyword.get(opts, :after)

    issues =
      opts
      |> issues_query()
      |> after_cursor(cursor)
      |> order_issues()
      |> limit(^(limit + 1))
      |> preload(:project)
      |> Repo.all()

    {page, remaining} = Enum.split(issues, limit)

    %{
      issues: page,
      next_cursor: next_cursor(page, remaining)
    }
  end

  def get_project_issue!(project_id, issue_id) do
    Repo.get_by!(Issue, project_id: project_id, id: issue_id)
  end

  def subscribe(project_id) do
    Phoenix.PubSub.subscribe(Faultline.PubSub, topic(project_id))
  end

  def subscribe_all do
    Phoenix.PubSub.subscribe(Faultline.PubSub, all_topic())
  end

  def broadcast_issue_change(%Issue{} = issue) do
    Phoenix.PubSub.broadcast(Faultline.PubSub, topic(issue.project_id), {:issue_changed, issue})
    Phoenix.PubSub.broadcast(Faultline.PubSub, all_topic(), {:issue_changed, issue})
  end

  def issue_matches_search?(%Issue{} = issue, search) when is_binary(search) do
    search = search |> String.trim() |> String.downcase()

    search == "" or
      [issue.title, issue.fingerprint]
      |> Enum.reject(&is_nil/1)
      |> Enum.any?(&(String.downcase(&1) |> String.contains?(search)))
  end

  def issue_matches_search?(%Issue{}, _search), do: true

  def issue_matches_filters?(%Issue{} = issue, opts) do
    project_id = Keyword.get(opts, :project_id)
    project_matches? = is_nil(project_id) or issue.project_id == project_id

    project_matches? and issue_matches_search?(issue, Keyword.get(opts, :search))
  end

  def with_project(%Issue{} = issue), do: Repo.preload(issue, :project)

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

  defp issues_query(opts) do
    Issue
    |> filter_project(Keyword.get(opts, :project_id))
    |> search_issues(Keyword.get(opts, :search))
  end

  defp filter_project(query, nil), do: query

  defp filter_project(query, project_id),
    do: where(query, [issue], issue.project_id == ^project_id)

  defp search_issues(query, nil), do: query

  defp search_issues(query, search) when is_binary(search) do
    case String.trim(search) do
      "" ->
        query

      search ->
        pattern = "%#{escape_like(search)}%"

        where(
          query,
          [issue],
          fragment("? ILIKE ? ESCAPE '\\'", issue.title, ^pattern) or
            fragment("? ILIKE ? ESCAPE '\\'", issue.fingerprint, ^pattern)
        )
    end
  end

  defp order_issues(query) do
    order_by(query, [issue], desc: issue.last_seen_at, desc: issue.id)
  end

  defp escape_like(search) do
    search
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp after_cursor(query, nil), do: query
  defp after_cursor(query, ""), do: query

  defp after_cursor(query, cursor) when is_binary(cursor) do
    case decode_cursor(cursor) do
      {:ok, last_seen_at, id} ->
        where(
          query,
          [issue],
          issue.last_seen_at < ^last_seen_at or
            (issue.last_seen_at == ^last_seen_at and issue.id < ^id)
        )

      :error ->
        query
    end
  end

  defp next_cursor(_page, []), do: nil
  defp next_cursor([], _remaining), do: nil

  defp next_cursor(page, _remaining) do
    issue = List.last(page)
    encode_cursor(issue)
  end

  defp encode_cursor(issue) do
    timestamp = DateTime.to_unix(issue.last_seen_at, :microsecond)
    "#{timestamp}:#{issue.id}"
  end

  defp decode_cursor(cursor) do
    with [timestamp, id] <- String.split(cursor, ":", parts: 2),
         {timestamp, ""} <- Integer.parse(timestamp),
         {:ok, id} <- Ecto.UUID.cast(id),
         {:ok, last_seen_at} <- DateTime.from_unix(timestamp, :microsecond) do
      {:ok, last_seen_at, id}
    else
      _ -> :error
    end
  end

  defp topic(project_id), do: "project:#{project_id}:issues"
  defp all_topic, do: "issues:all"
end
