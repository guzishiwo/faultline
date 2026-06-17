defmodule Faultline.InstanceSettings.RuntimeSetting do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  schema "runtime_settings" do
    field :key, :string, primary_key: true
    field :value, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
  end
end
