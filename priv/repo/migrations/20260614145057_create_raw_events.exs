defmodule Faultline.Repo.Migrations.CreateRawEvents do
  use Ecto.Migration

  def change do
    create table(:raw_events) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :event_id, :string, null: false
      add :source, :string, null: false
      add :payload_type, :string, null: false
      add :payload, :map, null: false
      add :auth, :map, null: false
      add :received_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:raw_events, [:project_id])
    create index(:raw_events, [:project_id, :event_id])
  end
end
