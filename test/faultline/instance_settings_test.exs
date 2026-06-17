defmodule Faultline.InstanceSettingsTest do
  use Faultline.DataCase, async: true

  alias Faultline.InstanceSettings
  alias Faultline.Projects

  test "returns the configured public DSN base URL before an override is saved" do
    assert InstanceSettings.public_dsn_base_url() == "http://localhost:4010"
  end

  test "saves a public DSN base URL and uses it for new project DSNs" do
    assert {:ok, settings} =
             InstanceSettings.update_public_dsn_base_url(%{
               "public_dsn_base_url" => "https://errors.example.com/base?ignored=true"
             })

    assert settings.public_dsn_base_url == "https://errors.example.com"
    assert InstanceSettings.public_dsn_base_url() == "https://errors.example.com"

    assert {:ok, project} = Projects.create_project(%{"name" => "Configured Host"})
    assert project.dsn =~ "@errors.example.com/#{project.project_number}"
  end

  test "rejects invalid public DSN base URLs" do
    assert {:error, changeset} =
             InstanceSettings.update_public_dsn_base_url(%{
               "public_dsn_base_url" => "ftp://errors.example.com"
             })

    assert "must start with http:// or https://" in errors_on(changeset).public_dsn_base_url
  end
end
