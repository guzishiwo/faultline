defmodule Faultline.Repo.Migrations.CreateAlertDeliveries do
  use Ecto.Migration

  def change do
    create table(:alert_deliveries) do
      add :trigger, :string, null: false
      add :channel, :string, null: false
      add :target, :string, null: false
      add :status, :string, null: false
      add :delivered_at, :utc_datetime_usec, null: false
      add :error, :text
      add :alert_rule_id, references(:alert_rules, on_delete: :delete_all), null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :issue_id, references(:issues, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:alert_deliveries, [:alert_rule_id])
    create index(:alert_deliveries, [:project_id])
    create index(:alert_deliveries, [:issue_id])
    create index(:alert_deliveries, [:alert_rule_id, :issue_id, :trigger, :delivered_at])
  end
end
