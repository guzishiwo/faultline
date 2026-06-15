defmodule Faultline.Projects.DSN do
  @moduledoc """
  Builds Sentry-compatible DSNs for projects.

  The SDK DSN path is the project number. Sentry SDKs use that value to call
  `/api/:project_id/store/` and `/api/:project_id/envelope/`.
  """

  alias Faultline.Projects.Project

  @spec build(Project.t(), String.t()) :: String.t()
  def build(
        %Project{project_number: project_number, public_key: public_key, secret_key: secret_key},
        base_url
      )
      when not is_nil(project_number) do
    uri =
      base_url
      |> URI.parse()
      |> Map.put(:userinfo, "#{public_key}:#{secret_key}")
      |> Map.put(:path, "/#{project_number}")
      |> Map.put(:query, nil)
      |> Map.put(:fragment, nil)

    URI.to_string(uri)
  end
end
