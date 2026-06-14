defmodule Faultline.Projects do
  @moduledoc """
  Project lifecycle and DSN generation.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Faultline.Projects.DSN
  alias Faultline.Projects.Project
  alias Faultline.Repo

  @default_dsn_base_url "http://localhost:4000"

  @doc """
  Lists projects ordered by newest first.
  """
  def list_projects do
    Project
    |> order_by([project], desc: project.inserted_at, desc: project.id)
    |> Repo.all()
  end

  @doc """
  Creates a project and stores its Sentry-compatible DSN.
  """
  def create_project(attrs, opts \\ []) do
    dsn_base_url = Keyword.get(opts, :dsn_base_url, configured_dsn_base_url())

    Multi.new()
    |> Multi.insert(:project, Project.create_changeset(%Project{}, attrs))
    |> Multi.update(:project_with_dsn, fn %{project: project} ->
      Project.update_dsn_changeset(project, DSN.build(project, dsn_base_url))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{project_with_dsn: project}} -> {:ok, project}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Returns an empty project changeset for forms.
  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.create_changeset(project, attrs)
  end

  defp configured_dsn_base_url do
    :faultline
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:dsn_base_url, @default_dsn_base_url)
  end
end
