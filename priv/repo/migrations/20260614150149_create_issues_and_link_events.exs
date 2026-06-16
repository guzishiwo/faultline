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

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:issues, [:project_id, :fingerprint])
    create index(:issues, [:project_id, :status])
    create index(:issues, [:project_id, :last_seen_at])

    alter table(:events) do
      add :issue_id, references(:issues, on_delete: :nilify_all)
    end

    create index(:events, [:issue_id])

    create table(:issue_search_documents) do
      add :issue_id, references(:issues, on_delete: :delete_all), null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :document, :text, null: false, default: ""
      add :tags, :text, null: false, default: ""
      add :release, :string
      add :environment, :string
      add :level, :string
      add :logger, :string
      add :platform, :string
      add :server_name, :string
      add :user_identifier, :string
      add :request_url, :string
      add :last_seen_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:issue_search_documents, [:issue_id])
    create index(:issue_search_documents, [:project_id])
    create index(:issue_search_documents, [:release])
    create index(:issue_search_documents, [:environment])
    create index(:issue_search_documents, [:level])
    create index(:issue_search_documents, [:last_seen_at])
  end
end
