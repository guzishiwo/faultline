defmodule Faultline.Repo.Migrations.AddRetentionAndDropRules do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :retention_days, :integer, null: false, default: 30
      add :retention_event_limit, :integer, null: false, default: 10_000
    end

    create table(:project_drop_rules) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :match_field, :string, null: false
      add :match_type, :string, null: false
      add :match_value, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:project_drop_rules, [:project_id])
    create index(:project_drop_rules, [:project_id, :enabled])
    create index(:raw_events, [:project_id, :received_at])
  end
end
