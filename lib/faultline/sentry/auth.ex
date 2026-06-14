defmodule Faultline.Sentry.Auth do
  @moduledoc """
  Parses the Sentry SDK auth forms used by store and envelope requests.
  """

  alias Faultline.Projects.Project

  @type t :: %{
          optional(:version) => String.t(),
          optional(:client) => String.t(),
          required(:public_key) => String.t(),
          optional(:secret_key) => String.t()
        }

  @spec parse(Plug.Conn.t()) :: {:ok, t()} | {:error, :missing_auth}
  def parse(conn) do
    case Plug.Conn.get_req_header(conn, "x-sentry-auth") do
      [header | _] -> parse_header(header)
      [] -> parse_query(conn.query_params)
    end
  end

  @spec authorized?(Project.t(), t()) :: boolean()
  def authorized?(%Project{} = project, %{public_key: public_key} = auth) do
    public_key == project.public_key and secret_authorized?(project, auth)
  end

  def authorized?(%Project{}, _auth), do: false

  defp secret_authorized?(project, %{secret_key: secret_key}) when is_binary(secret_key) do
    secret_key == project.secret_key
  end

  defp secret_authorized?(_project, _auth), do: true

  defp parse_header("Sentry " <> params) do
    params
    |> String.split(",", trim: true)
    |> Enum.reduce(%{}, fn part, acc ->
      case String.split(part, "=", parts: 2) do
        [key, value] -> put_known_param(acc, String.trim(key), unquote_value(String.trim(value)))
        _ -> acc
      end
    end)
    |> normalize()
  end

  defp parse_header(_header), do: {:error, :missing_auth}

  defp parse_query(params) do
    params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      put_known_param(acc, key, value)
    end)
    |> normalize()
  end

  defp put_known_param(acc, "sentry_version", value), do: Map.put(acc, :version, value)
  defp put_known_param(acc, "sentry_client", value), do: Map.put(acc, :client, value)
  defp put_known_param(acc, "sentry_key", value), do: Map.put(acc, :public_key, value)
  defp put_known_param(acc, "sentry_secret", value), do: Map.put(acc, :secret_key, value)
  defp put_known_param(acc, _key, _value), do: acc

  defp normalize(%{public_key: public_key} = auth)
       when is_binary(public_key) and public_key != "" do
    {:ok, auth}
  end

  defp normalize(_auth), do: {:error, :missing_auth}

  defp unquote_value("\"" <> value) do
    String.trim_trailing(value, "\"")
  end

  defp unquote_value(value), do: value
end
