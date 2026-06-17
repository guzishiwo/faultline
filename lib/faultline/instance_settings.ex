defmodule Faultline.InstanceSettings do
  @moduledoc """
  Runtime settings for the whole Faultline instance.
  """

  import Ecto.Changeset

  alias Faultline.InstanceSettings.RuntimeSetting
  alias Faultline.Repo

  @public_dsn_base_url_key "public_dsn_base_url"
  @default_public_dsn_base_url "http://localhost:4010"
  @settings_types %{public_dsn_base_url: :string}

  def public_dsn_base_url do
    case Repo.get(RuntimeSetting, @public_dsn_base_url_key) do
      nil -> configured_public_dsn_base_url()
      %RuntimeSetting{value: value} -> value
    end
  end

  def change_public_dsn_base_url(attrs \\ %{}) do
    public_dsn_base_url_changeset(%{public_dsn_base_url: public_dsn_base_url()}, attrs)
  end

  def update_public_dsn_base_url(attrs) do
    changeset =
      %{public_dsn_base_url: public_dsn_base_url()}
      |> public_dsn_base_url_changeset(attrs)

    if changeset.valid? do
      value = get_field(changeset, :public_dsn_base_url)
      now = DateTime.utc_now(:microsecond)

      %RuntimeSetting{}
      |> RuntimeSetting.changeset(%{key: @public_dsn_base_url_key, value: value})
      |> Repo.insert(
        on_conflict: [set: [value: value, updated_at: now]],
        conflict_target: :key
      )
      |> case do
        {:ok, _setting} -> {:ok, %{public_dsn_base_url: value}}
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, changeset}
    end
  end

  def configured_public_dsn_base_url do
    :faultline
    |> Application.get_env(Faultline.Projects, [])
    |> Keyword.get(:dsn_base_url, @default_public_dsn_base_url)
    |> normalize_public_dsn_base_url()
  end

  defp public_dsn_base_url_changeset(settings, attrs) do
    {settings, @settings_types}
    |> cast(attrs, [:public_dsn_base_url])
    |> validate_required([:public_dsn_base_url])
    |> validate_change(:public_dsn_base_url, &validate_public_dsn_base_url/2)
    |> normalize_public_dsn_base_url_change()
  end

  defp validate_public_dsn_base_url(:public_dsn_base_url, value) do
    case URI.parse(value || "") do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        []

      %URI{scheme: scheme} when scheme not in ["http", "https"] ->
        [public_dsn_base_url: "must start with http:// or https://"]

      _uri ->
        [public_dsn_base_url: "must include a host"]
    end
  end

  defp normalize_public_dsn_base_url_change(changeset) do
    if changeset.valid? do
      update_change(changeset, :public_dsn_base_url, &normalize_public_dsn_base_url/1)
    else
      changeset
    end
  end

  defp normalize_public_dsn_base_url(value) do
    uri = URI.parse(value)
    port = normalized_port(uri.scheme, uri.port)
    authority = if port, do: "#{uri.host}:#{port}", else: uri.host

    "#{uri.scheme}://#{authority}"
  end

  defp normalized_port("http", 80), do: nil
  defp normalized_port("https", 443), do: nil
  defp normalized_port(_scheme, nil), do: nil
  defp normalized_port(_scheme, port), do: port
end
