defmodule Faultline.Alerts.AlertRule do
  use Faultline.Schema

  import Ecto.Changeset

  alias Faultline.Alerts.AlertDelivery
  alias Faultline.Projects.Project

  @notify_on_values ~w(new_issue regression frequency)
  @channel_values ~w(email webhook slack)

  @type t :: %__MODULE__{}

  schema "alert_rules" do
    field :name, :string
    field :enabled, :boolean, default: true
    field :notify_on, :string
    field :channel, :string
    field :target, :string
    field :threshold_count, :integer, default: 1
    field :cooldown_seconds, :integer, default: 900

    belongs_to :project, Project
    has_many :alert_deliveries, AlertDelivery

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(alert_rule, attrs) do
    alert_rule
    |> cast(attrs, [
      :name,
      :enabled,
      :notify_on,
      :channel,
      :target,
      :threshold_count,
      :cooldown_seconds,
      :project_id
    ])
    |> validate_required([
      :name,
      :enabled,
      :notify_on,
      :channel,
      :target,
      :threshold_count,
      :cooldown_seconds,
      :project_id
    ])
    |> validate_length(:name, min: 2, max: 80)
    |> validate_inclusion(:notify_on, @notify_on_values)
    |> validate_inclusion(:channel, @channel_values)
    |> validate_target()
    |> validate_number(:threshold_count, greater_than: 0, less_than_or_equal_to: 1_000_000)
    |> validate_number(:cooldown_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 86_400
    )
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:name, name: :alert_rules_project_id_name_index)
  end

  defp validate_target(changeset) do
    case get_field(changeset, :channel) do
      "email" ->
        validate_format(changeset, :target, ~r/^[^\s]+@[^\s]+$/, message: "must be an email")

      channel when channel in ["webhook", "slack"] ->
        validate_url(changeset)

      _channel ->
        changeset
    end
  end

  defp validate_url(changeset) do
    validate_change(changeset, :target, fn :target, target ->
      uri = URI.parse(target)

      if uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "" do
        []
      else
        [target: "must be an http or https URL"]
      end
    end)
  end
end
