defmodule Faultline.Repo.Migrations.CreateAlertRules do
  use Ecto.Migration

  def change do
    create table(:alert_rules) do
      add :name, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :notify_on, :string, null: false
      add :channel, :string, null: false
      add :target, :string, null: false
      add :threshold_count, :integer, null: false, default: 1
      add :cooldown_seconds, :integer, null: false, default: 900
      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:alert_rules, [:project_id])
    create index(:alert_rules, [:project_id, :enabled])
    create unique_index(:alert_rules, [:project_id, :name])
  end
end
