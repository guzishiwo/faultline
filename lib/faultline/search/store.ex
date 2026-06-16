defmodule Faultline.Search.Store do
  @moduledoc """
  Behaviour for storage-specific search implementations.
  """

  alias Faultline.Events.Event
  alias Faultline.Issues.Issue
  alias Faultline.Search.Query

  @callback search_issues(Query.t(), keyword()) :: :all | [Ecto.UUID.t()]
  @callback search_events(Query.t(), Ecto.UUID.t(), keyword()) :: :all | [Ecto.UUID.t()]
  @callback sync_event(Event.t(), Issue.t()) :: {:ok, term()} | {:error, term()}
  @callback delete_event(Event.t()) :: :ok
  @callback delete_issue(Issue.t()) :: :ok
end
