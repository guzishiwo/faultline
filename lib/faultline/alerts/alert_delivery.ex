defmodule Faultline.Alerts.AlertDelivery do
  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Alerts.AlertRule
  alias Faultline.Issues.Issue
  alias Faultline.Projects.Project

  @statuses ~w(delivered failed suppressed)

  @type t :: %__MODULE__{}

  schema "alert_deliveries" do
    field :trigger, :string
    field :channel, :string
    field :target, :string
    field :status, :string
    field :delivered_at, :utc_datetime_usec
    field :error, :string

    belongs_to :alert_rule, AlertRule
    belongs_to :project, Project
    belongs_to :issue, Issue

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(alert_delivery, attrs) do
    alert_delivery
    |> cast(attrs, [
      :trigger,
      :channel,
      :target,
      :status,
      :delivered_at,
      :error,
      :alert_rule_id,
      :project_id,
      :issue_id
    ])
    |> validate_required([
      :trigger,
      :channel,
      :target,
      :status,
      :delivered_at,
      :alert_rule_id,
      :project_id,
      :issue_id
    ])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:alert_rule_id)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:issue_id)
  end
end
