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
end
