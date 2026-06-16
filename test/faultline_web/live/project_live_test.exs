defmodule FaultlineWeb.ProjectLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Faultline.Projects.Project
  alias Faultline.Repo
  alias Faultline.Projects

  setup :register_and_log_in_user

  test "lists an empty project registry", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "#projects")
    assert has_element?(view, "#new-project-link")
  end

  test "lists projects with platform logo and focused actions", %{conn: conn} do
    assert {:ok, project} =
             Projects.create_project(
               %{
                 "name" => "React Storefront",
                 "platform" => "react",
                 "rate_limit_max_events" => "250",
                 "rate_limit_window_seconds" => "30"
               },
               dsn_base_url: "https://errors.example.com"
             )

    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "#project-platform-logo-#{project.id}", "R")
    assert has_element?(view, "#project-platform-#{project.id}", "React")
    assert has_element?(view, "#project-open-link-#{project.id}", "React Storefront")
    assert has_element?(view, "#project-issues-link-#{project.id}", "Open triage")
    assert has_element?(view, "#project-setup-link-#{project.id}")
    assert has_element?(view, "#project-settings-link-#{project.id}")
    refute has_element?(view, "#projects-#{project.id} code")
  end

  test "creates a project from the form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    assert has_element?(view, "#project-platform-picker")
    assert has_element?(view, "#platform-option-react")

    {:ok, guide_view, _html} =
      view
      |> form("#project-form",
        project: %{
          name: "Web checkout",
          platform: "react",
          rate_limit_max_events: "500",
          rate_limit_window_seconds: "60"
        }
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/p/web-checkout/platform/getting-started")

    project = Repo.one!(Project)

    assert project.platform == "react"
    assert has_element?(guide_view, "#project-getting-started-page")
    assert has_element?(guide_view, "#getting-started-platform", "React")
    assert has_element?(guide_view, "#getting-started-dsn-value", project.dsn)
    assert has_element?(guide_view, "#install-command-npm", "@sentry/react")
    assert has_element?(guide_view, "#install-command-npm-code[phx-hook='CodeHighlight']")
    assert has_element?(guide_view, "#configure-sdk-code", project.dsn)
    assert has_element?(guide_view, "#configure-sdk-code[phx-hook='CodeHighlight']")
    refute has_element?(guide_view, "#getting-started-verify")
  end

  test "shows the unsure platform getting started fallback", %{conn: conn} do
    assert {:ok, project} =
             Faultline.Projects.create_project(%{"name" => "Unsure setup"},
               dsn_base_url: "https://errors.example.com"
             )

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/platform/getting-started")

    assert has_element?(view, "#getting-started-platform", "Not sure yet")
    assert has_element?(view, "#getting-started-dsn-value", project.dsn)
    assert has_element?(view, "#getting-started-install", "Pick a concrete platform later")
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

  test "filters platform options", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    assert has_element?(view, "#platform-option-react")

    view
    |> form("#project-form",
      platform_query: "rails",
      project: %{
        name: "Web checkout",
        platform: "other",
        rate_limit_max_events: "500",
        rate_limit_window_seconds: "60"
      }
    )
    |> render_change()

    assert has_element?(view, "#platform-option-rails")
    refute has_element?(view, "#platform-option-react")
  end
end
