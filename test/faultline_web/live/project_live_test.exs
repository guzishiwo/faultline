defmodule FaultlineWeb.ProjectLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Faultline.Projects.Project
  alias Faultline.Repo

  setup :register_and_log_in_user

  test "lists an empty project registry", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "#projects")
    assert has_element?(view, "#new-project-link")
  end

  test "creates a project from the form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    {:ok, index_view, _html} =
      view
      |> form("#project-form",
        project: %{
          name: "Web checkout",
          rate_limit_max_events: "500",
          rate_limit_window_seconds: "60"
        }
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/projects")

    project = Repo.one!(Project)

    assert has_element?(index_view, "#projects-#{project.id}")
    assert has_element?(index_view, "#project-open-link-#{project.id}")
    assert has_element?(index_view, "#project-dsn-summary-#{project.id}")
    assert has_element?(index_view, "#project-dsn-#{project.id}")
    assert has_element?(index_view, "#project-issues-link-#{project.id}")
    assert has_element?(index_view, "#project-alerts-link-#{project.id}")
  end

  test "validates the project form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    view
    |> form("#project-form",
      project: %{
        name: "",
        rate_limit_max_events: "0",
        rate_limit_window_seconds: "0"
      }
    )
    |> render_change()

    assert has_element?(view, "#project-form")
    assert Repo.aggregate(Project, :count) == 0
  end
end
