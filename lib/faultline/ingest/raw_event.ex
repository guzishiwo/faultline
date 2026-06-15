defmodule Faultline.Ingest.RawEvent do
  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Projects.Project

  @type t :: %__MODULE__{}

  schema "raw_events" do
    field :event_id, :string
    field :source, :string
    field :payload_type, :string
    field :payload, :map
    field :auth, :map
    field :received_at, :utc_datetime_usec

    belongs_to :project, Project

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(raw_event, attrs) do
    raw_event
    |> cast(attrs, [:event_id, :source, :payload_type, :payload, :auth, :received_at, :project_id])
    |> validate_required([
      :event_id,
      :source,
      :payload_type,
      :payload,
      :auth,
      :received_at,
      :project_id
    ])
    |> validate_inclusion(:source, ["store", "envelope"])
    |> validate_inclusion(:payload_type, ["event"])
    |> foreign_key_constraint(:project_id)
  end
end
