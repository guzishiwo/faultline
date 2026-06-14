defmodule Faultline.Events do
  @moduledoc """
  Normalized event storage and lookup.
  """

  import Ecto.Query, warn: false

  alias Faultline.Events.Event
  alias Faultline.Events.Normalizer
  alias Faultline.Ingest.RawEvent
  alias Faultline.Issues
  alias Faultline.Repo

  @doc """
  Normalizes a raw Sentry event into the queryable event table.
  """
  def normalize_raw_event(%RawEvent{} = raw_event) do
    %Event{}
    |> Event.changeset(Normalizer.normalize(raw_event))
    |> Repo.insert()
    |> case do
      {:ok, event} ->
        case Issues.group_event(event) do
          {:ok, _issue, grouped_event} -> {:ok, grouped_event}
          {:error, reason} -> {:error, reason}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists normalized events for a project, newest first.
  """
  def list_project_events(project_id) do
    Event
    |> where([event], event.project_id == ^project_id)
    |> order_by([event], desc: event.occurred_at, desc: event.id)
    |> Repo.all()
  end

  @doc """
  Lists the latest events for an issue.
  """
  def list_issue_events(issue_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Event
    |> where([event], event.issue_id == ^issue_id)
    |> order_by([event], desc: event.occurred_at, desc: event.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets an issue event and its raw event payload.
  """
  def get_issue_event_with_raw!(issue_id, event_id) do
    Event
    |> where([event], event.issue_id == ^issue_id)
    |> where([event], event.id == ^event_id)
    |> preload(:raw_event)
    |> Repo.one!()
  end
end
