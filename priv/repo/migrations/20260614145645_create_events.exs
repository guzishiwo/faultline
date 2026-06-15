defmodule Faultline.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :raw_event_id, references(:raw_events, on_delete: :delete_all), null: false
      add :event_id, :string, null: false
      add :occurred_at, :utc_datetime_usec, null: false
      add :platform, :string
      add :logger, :string
      add :level, :string
      add :culprit, :string
      add :message, :string
      add :exception_type, :string
      add :exception_value, :string
      add :release, :string
      add :environment, :string
      add :server_name, :string
      add :user_identifier, :string
      add :request_url, :string
      add :details, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:events, [:raw_event_id])
    create index(:events, [:project_id, :event_id])
    create index(:events, [:project_id, :occurred_at])
    create index(:events, [:project_id, :level])
    create index(:events, [:project_id, :environment])
  end
end
