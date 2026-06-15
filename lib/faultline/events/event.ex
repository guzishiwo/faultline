defmodule Faultline.Events.Event do
  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Ingest.RawEvent
  alias Faultline.Issues.Issue
  alias Faultline.Projects.Project

  @type t :: %__MODULE__{}

  schema "events" do
    field :event_id, :string
    field :occurred_at, :utc_datetime_usec
    field :platform, :string
    field :logger, :string
    field :level, :string
    field :culprit, :string
    field :message, :string
    field :exception_type, :string
    field :exception_value, :string
    field :release, :string
    field :environment, :string
    field :server_name, :string
    field :user_identifier, :string
    field :request_url, :string
    field :details, :map, default: %{}

    belongs_to :project, Project
    belongs_to :raw_event, RawEvent
    belongs_to :issue, Issue

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :event_id,
      :occurred_at,
      :platform,
      :logger,
      :level,
      :culprit,
      :message,
      :exception_type,
      :exception_value,
      :release,
      :environment,
      :server_name,
      :user_identifier,
      :request_url,
      :details,
      :project_id,
      :raw_event_id,
      :issue_id
    ])
    |> validate_required([:event_id, :occurred_at, :details, :project_id, :raw_event_id])
    |> validate_length(:event_id, min: 1, max: 64)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:raw_event_id)
    |> foreign_key_constraint(:issue_id)
    |> unique_constraint(:raw_event_id)
  end

  def issue_changeset(event, %Issue{} = issue) do
    event
    |> change(issue_id: issue.id)
    |> foreign_key_constraint(:issue_id)
  end
end
