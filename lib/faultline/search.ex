defmodule Faultline.Search do
  @moduledoc """
  Storage-neutral search boundary.
  """

  alias Faultline.Events.Event
  alias Faultline.Issues.Issue
  alias Faultline.Search.Query
  alias Faultline.Search.Store.SQLite

  @spec parse(String.t() | nil) :: Query.t()
  def parse(query), do: Query.parse(query)

  @spec search_issues(String.t() | Query.t() | nil, keyword()) :: :all | [Ecto.UUID.t()]
  def search_issues(query, opts \\ []) do
    query
    |> to_query()
    |> store().search_issues(opts)
  end

  @spec search_events(String.t() | Query.t() | nil, Ecto.UUID.t(), keyword()) ::
          :all | [Ecto.UUID.t()]
  def search_events(query, issue_id, opts \\ []) do
    query
    |> to_query()
    |> store().search_events(issue_id, opts)
  end

  @spec sync_event(Event.t(), Issue.t()) :: {:ok, term()} | {:error, term()}
  def sync_event(%Event{} = event, %Issue{} = issue), do: store().sync_event(event, issue)

  @spec delete_event(Event.t()) :: :ok
  def delete_event(%Event{} = event), do: store().delete_event(event)

  @spec delete_issue(Issue.t()) :: :ok
  def delete_issue(%Issue{} = issue), do: store().delete_issue(issue)

  defp to_query(%Query{} = query), do: query
  defp to_query(query), do: Query.parse(query)

  defp store, do: SQLite
end
