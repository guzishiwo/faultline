defmodule Faultline.Search.IssueDocument do
  @moduledoc """
  Issue-level search document for the SQLite search store.
  """

  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Issues.Issue
  alias Faultline.Projects.Project

  @type t :: %__MODULE__{}

  schema "issue_search_documents" do
    field :title, :string, default: ""
    field :body, :string, default: ""
    field :last_seen_at, :utc_datetime_usec

    belongs_to :issue, Issue
    belongs_to :project, Project

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :issue_id,
      :project_id,
      :title,
      :body,
      :last_seen_at
    ])
    |> validate_required([:issue_id, :project_id, :title, :body, :last_seen_at])
    |> foreign_key_constraint(:issue_id)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:issue_id)
  end
end
