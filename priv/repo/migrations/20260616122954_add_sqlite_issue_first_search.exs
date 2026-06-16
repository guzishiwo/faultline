defmodule Faultline.Repo.Migrations.AddSqliteIssueFirstSearch do
  use Ecto.Migration

  def up do
    drop_if_exists index(:issue_search_documents, [:last_seen_at])
    drop_if_exists index(:issue_search_documents, [:level])
    drop_if_exists index(:issue_search_documents, [:environment])
    drop_if_exists index(:issue_search_documents, [:release])
    drop_if_exists index(:issue_search_documents, [:project_id])

    alter table(:issue_search_documents) do
      remove :document
      remove :tags
      remove :release
      remove :environment
      remove :level
      remove :logger
      remove :platform
      remove :server_name
      remove :user_identifier
      remove :request_url
      add :title, :text, null: false, default: ""
      add :body, :text, null: false, default: ""
    end

    create index(:issue_search_documents, [:project_id, :last_seen_at])

    create table(:issue_tag_values) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :issue_id, references(:issues, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :string, null: false
      add :event_count, :integer, null: false, default: 0
      add :first_seen_at, :utc_datetime_usec, null: false
      add :last_seen_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:issue_tag_values, [:project_id, :issue_id, :key, :value])
    create index(:issue_tag_values, [:project_id, :key, :value, :issue_id])
    create index(:issue_tag_values, [:issue_id, :key, :value])

    create table(:event_tag_values) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :issue_id, references(:issues, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :string, null: false
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:event_tag_values, [:project_id, :event_id, :key, :value])
    create index(:event_tag_values, [:project_id, :key, :value, :issue_id])
    create index(:event_tag_values, [:issue_id, :key, :value, :event_id])
    create index(:event_tag_values, [:issue_id, :occurred_at])

    execute("""
    CREATE VIRTUAL TABLE issue_search_fts USING fts5(
      issue_id UNINDEXED,
      title,
      body,
      tokenize='unicode61'
    )
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS issue_search_fts")
    drop table(:event_tag_values)
    drop table(:issue_tag_values)

    drop_if_exists index(:issue_search_documents, [:project_id, :last_seen_at])

    alter table(:issue_search_documents) do
      remove :title
      remove :body
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
    end

    create index(:issue_search_documents, [:project_id])
    create index(:issue_search_documents, [:release])
    create index(:issue_search_documents, [:environment])
    create index(:issue_search_documents, [:level])
    create index(:issue_search_documents, [:last_seen_at])
  end
end
