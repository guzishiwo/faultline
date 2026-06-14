defmodule Faultline.Repo.Migrations.CreateIssuesAndLinkEvents do
  use Ecto.Migration

  def change do
    create table(:issues) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :fingerprint, :string, null: false
      add :title, :string, null: false
      add :status, :string, null: false, default: "unresolved"
      add :first_seen_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec, null: false
      add :event_count, :integer, null: false, default: 0
      add :affected_user_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:issues, [:project_id, :fingerprint])
    create index(:issues, [:project_id, :status])
    create index(:issues, [:project_id, :last_seen_at])

    alter table(:events) do
      add :issue_id, references(:issues, on_delete: :nilify_all)
    end

    create index(:events, [:issue_id])
  end
end
