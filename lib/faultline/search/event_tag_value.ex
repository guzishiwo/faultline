defmodule Faultline.Search.EventTagValue do
  @moduledoc """
  Per-event searchable tag value for issue drill-down.
  """

  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Events.Event
  alias Faultline.Issues.Issue
  alias Faultline.Projects.Project

  @type t :: %__MODULE__{}

  schema "event_tag_values" do
    field :key, :string
    field :value, :string
    field :occurred_at, :utc_datetime_usec

    belongs_to :project, Project
    belongs_to :issue, Issue
    belongs_to :event, Event

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(tag_value, attrs) do
    tag_value
    |> cast(attrs, [:project_id, :issue_id, :event_id, :key, :value, :occurred_at])
    |> validate_required([:project_id, :issue_id, :event_id, :key, :value, :occurred_at])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:issue_id)
    |> foreign_key_constraint(:event_id)
    |> unique_constraint([:project_id, :event_id, :key, :value])
  end
end
