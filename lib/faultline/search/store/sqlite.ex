defmodule Faultline.Search.Store.SQLite do
  @moduledoc """
  SQLite implementation of Faultline's issue-first search boundary.
  """

  @behaviour Faultline.Search.Store

  import Ecto.Query, warn: false

  alias Faultline.Events.Event
  alias Faultline.Issues.Issue
  alias Faultline.Projects.Project
  alias Faultline.Repo
  alias Faultline.Search.EventTagValue
  alias Faultline.Search.IssueDocument
  alias Faultline.Search.IssueTagValue
  alias Faultline.Search.Query

  @system_tag_keys ~w(
    environment
    level
    logger
    platform
    release
    request_url
    server
    server_name
    trace
    url
    user
    user_identifier
  )

  @impl true
  def search_issues(%Query{} = query, opts) do
    if searchable_issue_query?(query, opts) do
      Issue
      |> apply_project_opt(Keyword.get(opts, :project_id))
      |> apply_reserved_issue_filters(query)
      |> apply_issue_tag_filters(query.tag_filters)
      |> apply_issue_text_terms(query.text_terms)
      |> select([issue], issue.id)
      |> Repo.all()
    else
      :all
    end
  end

  @impl true
  def search_events(%Query{} = query, issue_id, _opts) do
    if query.tag_filters == [] and event_reserved_filters(query) == [] do
      :all
    else
      Event
      |> where([event], event.issue_id == ^issue_id)
      |> apply_event_reserved_filters(query)
      |> apply_event_tag_filters(query.tag_filters)
      |> order_by([event], desc: event.occurred_at, desc: event.id)
      |> select([event], event.id)
      |> Repo.all()
    end
  end

  @impl true
  def sync_event(%Event{} = event, %Issue{} = issue) do
    Repo.transaction(fn ->
      tags = event_tags(event)

      insert_event_tags(event, issue, tags)
      rebuild_issue_tag_rollups(issue)
      document = upsert_issue_document(event, issue)
      sync_fts_document!(document)
    end)
  end

  @impl true
  def delete_event(%Event{} = event) do
    EventTagValue
    |> where([tag], tag.event_id == ^event.id)
    |> Repo.delete_all()

    :ok
  end

  @impl true
  def delete_issue(%Issue{} = issue) do
    IssueTagValue
    |> where([tag], tag.issue_id == ^issue.id)
    |> Repo.delete_all()

    EventTagValue
    |> where([tag], tag.issue_id == ^issue.id)
    |> Repo.delete_all()

    if document = Repo.get_by(IssueDocument, issue_id: issue.id) do
      delete_fts_document!(document)
      Repo.delete!(document)
    end

    :ok
  end

  defp searchable_issue_query?(query, opts) do
    query.reserved_filters != [] or query.tag_filters != [] or query.text_terms != [] or
      Keyword.get(opts, :project_id) not in [nil, ""]
  end

  defp apply_project_opt(query, nil), do: query
  defp apply_project_opt(query, ""), do: query

  defp apply_project_opt(query, project_id),
    do: where(query, [issue], issue.project_id == ^project_id)

  defp apply_reserved_issue_filters(query, %Query{} = parsed) do
    Enum.reduce(parsed.reserved_filters, query, fn
      {"project", project}, query ->
        project_ids = resolve_project_ids(project)

        if project_ids == [] do
          where(query, false)
        else
          where(query, [issue], issue.project_id in ^project_ids)
        end

      {"status", status}, query ->
        where(query, [issue], issue.status == ^normalize_value(status))

      {"issue", issue_id}, query ->
        where(query, [issue], issue.id == ^issue_id or issue.fingerprint == ^issue_id)
    end)
  end

  defp apply_issue_tag_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, query ->
      key = normalize_value(key)
      value = normalize_value(value)

      where(
        query,
        [issue],
        fragment(
          "EXISTS (SELECT 1 FROM issue_tag_values AS tag WHERE tag.issue_id = ? AND tag.key = ? AND tag.value = ?)",
          issue.id,
          ^key,
          ^value
        )
      )
    end)
  end

  defp apply_issue_text_terms(query, []), do: query

  defp apply_issue_text_terms(query, terms) do
    match = fts_match(terms)

    where(
      query,
      [issue],
      fragment(
        "EXISTS (SELECT 1 FROM issue_search_fts WHERE issue_search_fts.issue_id = ? AND issue_search_fts MATCH ?)",
        issue.id,
        ^match
      )
    )
  end

  defp apply_event_reserved_filters(query, %Query{} = parsed) do
    Enum.reduce(event_reserved_filters(parsed), query, fn
      {"issue", issue_id}, query ->
        where(query, [event], event.issue_id == ^issue_id)

      {_key, _value}, query ->
        query
    end)
  end

  defp event_reserved_filters(%Query{} = parsed) do
    Enum.filter(parsed.reserved_filters, fn {key, _value} -> key == "issue" end)
  end

  defp apply_event_tag_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, query ->
      key = normalize_value(key)
      value = normalize_value(value)

      where(
        query,
        [event],
        fragment(
          "EXISTS (SELECT 1 FROM event_tag_values AS tag WHERE tag.event_id = ? AND tag.key = ? AND tag.value = ?)",
          event.id,
          ^key,
          ^value
        )
      )
    end)
  end

  defp insert_event_tags(_event, _issue, []), do: :ok

  defp insert_event_tags(event, issue, tags) do
    now = DateTime.utc_now(:microsecond)

    rows =
      Enum.map(tags, fn {key, value} ->
        %{
          project_id: issue.project_id,
          issue_id: issue.id,
          event_id: event.id,
          key: key,
          value: value,
          occurred_at: event.occurred_at,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(EventTagValue, rows,
      on_conflict: :nothing,
      conflict_target: [:project_id, :event_id, :key, :value]
    )

    :ok
  end

  defp rebuild_issue_tag_rollups(issue) do
    IssueTagValue
    |> where([tag], tag.issue_id == ^issue.id)
    |> Repo.delete_all()

    now = DateTime.utc_now(:microsecond)

    rows =
      EventTagValue
      |> where([tag], tag.issue_id == ^issue.id)
      |> group_by([tag], [tag.project_id, tag.issue_id, tag.key, tag.value])
      |> select([tag], %{
        project_id: tag.project_id,
        issue_id: tag.issue_id,
        key: tag.key,
        value: tag.value,
        event_count: count(tag.event_id),
        first_seen_at: min(tag.occurred_at),
        last_seen_at: max(tag.occurred_at)
      })
      |> Repo.all()
      |> Enum.map(fn row ->
        row
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)
      end)

    if rows != [] do
      Repo.insert_all(IssueTagValue, rows)
    end

    :ok
  end

  defp upsert_issue_document(event, issue) do
    existing = Repo.get_by(IssueDocument, issue_id: issue.id)
    body = merge_lines(existing && existing.body, document_body(event, issue))

    document =
      case existing do
        nil -> %IssueDocument{}
        document -> document
      end

    document
    |> IssueDocument.changeset(%{
      issue_id: issue.id,
      project_id: issue.project_id,
      title: issue.title,
      body: body,
      last_seen_at: issue.last_seen_at
    })
    |> Repo.insert_or_update!()
  end

  defp sync_fts_document!(%IssueDocument{} = document) do
    Repo.query!("DELETE FROM issue_search_fts WHERE issue_id = ?", [document.issue_id])

    Repo.query!(
      "INSERT INTO issue_search_fts(issue_id, title, body) VALUES (?, ?, ?)",
      [document.issue_id, document.title, document.body]
    )

    document
  end

  defp delete_fts_document!(%IssueDocument{} = document) do
    Repo.query!("DELETE FROM issue_search_fts WHERE issue_id = ?", [document.issue_id])
    :ok
  end

  defp document_body(event, issue) do
    frames = get_in(event.details, ["exception", "stacktrace_frames"]) || []

    frame_values =
      frames
      |> Enum.filter(& &1["in_app"])
      |> Enum.flat_map(fn frame ->
        [
          frame["function"],
          frame["module"],
          frame["filename"],
          frame["abs_path"]
        ]
      end)

    tag_values =
      event
      |> event_tags()
      |> Enum.flat_map(fn {key, value} -> [key, value] end)

    [
      issue.title,
      issue.fingerprint,
      event.event_id,
      event.platform,
      event.logger,
      event.level,
      event.culprit,
      event.message,
      event.exception_type,
      event.exception_value,
      event.release,
      event.environment,
      event.server_name,
      event.user_identifier,
      event.request_url,
      frame_values,
      tag_values
    ]
    |> normalize_lines()
  end

  defp event_tags(event) do
    sdk_tags =
      case event.details do
        %{"tags" => tags} when is_map(tags) -> tags
        _ -> %{}
      end

    trace_id = get_in(event.details || %{}, ["contexts", "trace", "trace_id"])

    system_tags = %{
      "environment" => event.environment,
      "level" => event.level,
      "logger" => event.logger,
      "platform" => event.platform,
      "release" => event.release,
      "request_url" => event.request_url,
      "server" => event.server_name,
      "server_name" => event.server_name,
      "trace" => trace_id,
      "url" => event.request_url,
      "user" => event.user_identifier,
      "user_identifier" => event.user_identifier
    }

    system_tags
    |> Map.merge(sdk_tags)
    |> Enum.map(fn {key, value} -> {normalize_value(key), normalize_value(value)} end)
    |> Enum.reject(fn {key, value} -> key == "" or value == "" end)
    |> Enum.filter(fn {key, _value} -> key in @system_tag_keys or is_binary(key) end)
    |> Enum.uniq()
  end

  defp resolve_project_ids(project) do
    project_id =
      case Ecto.UUID.cast(project) do
        {:ok, project_id} -> project_id
        :error -> nil
      end

    Project
    |> where([project_record], project_record.slug == ^project or project_record.name == ^project)
    |> maybe_or_project_id(project_id)
    |> select([project_record], project_record.id)
    |> Repo.all()
  end

  defp maybe_or_project_id(query, nil), do: query

  defp maybe_or_project_id(query, project_id) do
    or_where(query, [project_record], project_record.id == ^project_id)
  end

  defp merge_lines(nil, text), do: text
  defp merge_lines("", text), do: text

  defp merge_lines(existing, text) do
    [existing, text]
    |> Enum.join("\n")
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.join("\n")
  end

  defp normalize_lines(values) do
    values
    |> List.wrap()
    |> List.flatten()
    |> Enum.reject(&blank?/1)
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.join("\n")
  end

  defp normalize_value(nil), do: ""

  defp normalize_value(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

  defp fts_match(terms) do
    terms
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.replace(&1, "\"", "\"\""))
    |> Enum.map(&~s("#{&1}"*))
    |> Enum.join(" ")
  end
end
