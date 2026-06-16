defmodule Faultline.Repo.Migrations.AddPlatformToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :platform, :string, null: false, default: "other"
    end
  end
end
