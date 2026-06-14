defmodule Faultline.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :public_key, :string, null: false
      add :secret_key, :string, null: false
      add :dsn, :string, null: false
      add :rate_limit_max_events, :integer, null: false, default: 1000
      add :rate_limit_window_seconds, :integer, null: false, default: 60

      timestamps(type: :utc_datetime)
    end

    create unique_index(:projects, [:slug])
    create unique_index(:projects, [:public_key])
  end
end
