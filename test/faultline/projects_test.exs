defmodule Faultline.ProjectsTest do
  use Faultline.DataCase, async: true

  alias Faultline.Projects
  alias Faultline.Projects.DSN
  alias Faultline.Projects.Project

  describe "projects" do
    test "create_project/2 creates keys, rate limits, and a Sentry-compatible DSN" do
      assert {:ok, project} =
               Projects.create_project(
                 %{
                   "name" => "Checkout API",
                   "rate_limit_max_events" => "250",
                   "rate_limit_window_seconds" => "30"
                 },
                 dsn_base_url: "https://errors.example.com"
               )

      assert project.name == "Checkout API"
      assert project.slug == "checkout-api"
      assert project.rate_limit_max_events == 250
      assert project.rate_limit_window_seconds == 30
      assert String.at(project.id, 14) == "7"
      assert is_integer(project.project_number)
      assert project.project_number > 0
      assert byte_size(project.public_key) == 32
      assert byte_size(project.secret_key) == 32
      assert project.public_key =~ ~r/^[a-f0-9]{32}$/
      assert project.secret_key =~ ~r/^[a-f0-9]{32}$/

      assert project.dsn ==
               "https://#{project.public_key}:#{project.secret_key}@errors.example.com/#{project.project_number}"
    end

    test "list_projects/0 returns created projects newest first" do
      assert {:ok, older} =
               Projects.create_project(%{"name" => "Older"},
                 dsn_base_url: "https://errors.example.com"
               )

      assert {:ok, newer} =
               Projects.create_project(%{"name" => "Newer"},
                 dsn_base_url: "https://errors.example.com"
               )

      assert [^newer, ^older] = Projects.list_projects()
    end

    test "create_project/2 validates required settings" do
      assert {:error, changeset} =
               Projects.create_project(
                 %{
                   "name" => "",
                   "rate_limit_max_events" => "0",
                   "rate_limit_window_seconds" => "0"
                 },
                 dsn_base_url: "https://errors.example.com"
               )

      assert "can't be blank" in errors_on(changeset).name
      assert "must be greater than 0" in errors_on(changeset).rate_limit_max_events
      assert "must be greater than 0" in errors_on(changeset).rate_limit_window_seconds
    end
  end

  describe "dsn generation" do
    test "build/2 strips any base path, query, and fragment" do
      project = %Project{
        id: "1a78e838-8532-43f8-96fe-080ae20657ad",
        project_number: 42,
        public_key: "public",
        secret_key: "secret"
      }

      assert DSN.build(project, "https://errors.example.com/base?team=ops#fragment") ==
               "https://public:secret@errors.example.com/42"
    end
  end
end
