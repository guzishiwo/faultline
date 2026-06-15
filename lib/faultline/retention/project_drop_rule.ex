defmodule Faultline.Retention.ProjectDropRule do
  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Projects.Project

  @fields ~w(exception_type message culprit logger level environment release)
  @types ~w(contains equals)

  @type t :: %__MODULE__{}

  schema "project_drop_rules" do
    field :name, :string
    field :enabled, :boolean, default: true
    field :match_field, :string
    field :match_type, :string
    field :match_value, :string

    belongs_to :project, Project

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(drop_rule, attrs) do
    drop_rule
    |> cast(attrs, [:name, :enabled, :match_field, :match_type, :match_value, :project_id])
    |> validate_required([:name, :enabled, :match_field, :match_type, :match_value, :project_id])
    |> validate_length(:name, min: 2, max: 80)
    |> validate_length(:match_value, min: 1, max: 500)
    |> validate_inclusion(:match_field, @fields)
    |> validate_inclusion(:match_type, @types)
    |> foreign_key_constraint(:project_id)
  end

  def fields, do: @fields
  def types, do: @types
end
