defmodule Faultline.Projects do
  @moduledoc """
  Project lifecycle and DSN generation.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Faultline.Events.Event
  alias Faultline.Ingest.RawEvent
  alias Faultline.Issues.Issue
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
  Gets a single project.
  """
  def get_project!(id), do: Repo.get!(Project, id)

  def get_project_by_slug!(slug), do: Repo.get_by!(Project, slug: slug)

  def get_project_by_route_param!(%{"project_slug" => slug}), do: get_project_by_slug!(slug)
  def get_project_by_route_param!(%{"project_id" => id}), do: get_project!(id)

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

  def project_platform_categories, do: Project.platform_categories()
  def project_platforms, do: Project.platforms()
  def project_platform_label(platform_id), do: Project.platform_label(platform_id)

  def update_project_settings(%Project{} = project, attrs) do
    project
    |> Project.settings_changeset(attrs)
    |> Repo.update()
  end

  def change_project_settings(%Project{} = project, attrs \\ %{}) do
    Project.settings_changeset(project, attrs)
  end

  def get_project_usage!(project_or_id)

  def get_project_usage!(%Project{} = project), do: project_usage(project)

  def get_project_usage!(id) do
    id
    |> get_project!()
    |> project_usage()
  end

  defp project_usage(%Project{} = project) do
    %{
      project: project,
      raw_event_count: count_project(RawEvent, project.id),
      event_count: count_project(Event, project.id),
      issue_count: count_project(Issue, project.id),
      earliest_event_at: aggregate_project(Event, project.id, :min, :occurred_at),
      latest_event_at: aggregate_project(Event, project.id, :max, :occurred_at)
    }
  end

  defp count_project(schema, project_id) do
    schema
    |> where([record], record.project_id == ^project_id)
    |> Repo.aggregate(:count)
  end

  defp aggregate_project(schema, project_id, aggregate, field) do
    schema
    |> where([record], record.project_id == ^project_id)
    |> Repo.aggregate(aggregate, field)
  end

  defp configured_dsn_base_url do
    :faultline
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:dsn_base_url, @default_dsn_base_url)
  end
end
