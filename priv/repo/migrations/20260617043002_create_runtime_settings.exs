defmodule Faultline.Repo.Migrations.CreateRuntimeSettings do
  use Ecto.Migration

  def change do
    create table(:runtime_settings, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
