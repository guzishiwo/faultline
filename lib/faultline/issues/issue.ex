defmodule Faultline.Issues.Issue do
  use Ecto.Schema

  import Ecto.Changeset

  alias Faultline.Events.Event
  alias Faultline.Projects.Project

  @statuses ~w(unresolved resolved ignored)

  @type t :: %__MODULE__{}

  schema "issues" do
    field :fingerprint, :string
    field :title, :string
    field :status, :string, default: "unresolved"
    field :first_seen_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :event_count, :integer, default: 0
    field :affected_user_count, :integer, default: 0

    belongs_to :project, Project
    has_many :events, Event

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(issue, attrs) do
    issue
    |> cast(attrs, [
      :project_id,
      :fingerprint,
      :title,
      :status,
      :first_seen_at,
      :last_seen_at,
      :event_count,
      :affected_user_count
    ])
    |> validate_required([
      :project_id,
      :fingerprint,
      :title,
      :status,
      :first_seen_at,
      :last_seen_at,
      :event_count,
      :affected_user_count
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:event_count, greater_than_or_equal_to: 0)
    |> validate_number(:affected_user_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:fingerprint, name: :issues_project_id_fingerprint_index)
  end

  def status_changeset(issue, status) do
    issue
    |> change(status: status)
    |> validate_inclusion(:status, @statuses)
  end
end
