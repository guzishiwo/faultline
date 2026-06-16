defmodule Faultline.Search.IssueTagValue do
  @moduledoc """
  Issue-level rollup of searchable event tags.
  """

  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Issues.Issue
  alias Faultline.Projects.Project

  @type t :: %__MODULE__{}

  schema "issue_tag_values" do
    field :key, :string
    field :value, :string
    field :event_count, :integer, default: 0
    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec

    belongs_to :project, Project
    belongs_to :issue, Issue

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(tag_value, attrs) do
    tag_value
    |> cast(attrs, [
      :project_id,
      :issue_id,
      :key,
      :value,
      :event_count,
      :first_seen_at,
      :last_seen_at
    ])
    |> validate_required([
      :project_id,
      :issue_id,
      :key,
      :value,
      :event_count,
      :first_seen_at,
      :last_seen_at
    ])
    |> validate_number(:event_count, greater_than: 0)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:issue_id)
    |> unique_constraint([:project_id, :issue_id, :key, :value])
  end
end
