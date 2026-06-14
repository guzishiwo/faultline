defmodule Faultline.Projects.Project do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "projects" do
    field :name, :string
    field :slug, :string
    field :public_key, :string
    field :secret_key, :string
    field :dsn, :string
    field :rate_limit_max_events, :integer, default: 1000
    field :rate_limit_window_seconds, :integer, default: 60

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :rate_limit_max_events, :rate_limit_window_seconds])
    |> validate_required([:name, :rate_limit_max_events, :rate_limit_window_seconds])
    |> validate_length(:name, min: 2, max: 80)
    |> validate_number(:rate_limit_max_events, greater_than: 0, less_than_or_equal_to: 1_000_000)
    |> validate_number(:rate_limit_window_seconds, greater_than: 0, less_than_or_equal_to: 86_400)
    |> put_slug()
    |> put_keys()
    |> put_placeholder_dsn()
    |> unique_constraint(:slug)
    |> unique_constraint(:public_key)
  end

  @doc false
  def update_dsn_changeset(project, dsn) do
    project
    |> change(dsn: dsn)
    |> validate_required([:dsn])
  end

  defp put_slug(changeset) do
    name = get_field(changeset, :name)

    if is_binary(name) do
      put_change(changeset, :slug, slugify(name))
    else
      changeset
    end
  end

  defp put_keys(changeset) do
    changeset
    |> put_change(:public_key, random_key())
    |> put_change(:secret_key, random_key())
  end

  defp put_placeholder_dsn(changeset) do
    put_change(changeset, :dsn, "pending")
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> ensure_slug()
  end

  defp ensure_slug(""), do: "project"
  defp ensure_slug(slug), do: slug

  defp random_key do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
