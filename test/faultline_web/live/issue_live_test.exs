defmodule FaultlineWeb.IssueLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Faultline.Events
  alias Faultline.Ingest.RawEvent
  alias Faultline.Projects
  alias Faultline.Repo

  @fixtures Path.expand("../../fixtures/sentry_events", __DIR__)

  test "lists project issues and links to details", %{conn: conn} do
    project = project_fixture()
    event = event_fixture(project, "javascript.json")

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/issues")

    assert has_element?(view, "#issues")
    assert has_element?(view, "#issues-#{event.issue_id}")
  end

  test "loads more issues with keyset pagination", %{conn: conn} do
    project = project_fixture()

    events =
      for index <- 1..21 do
        event_fixture(project, "javascript.json", %{
          "event_id" => String.pad_leading(Integer.to_string(index), 32, "0"),
          "culprit" => "checkout.step.#{index}",
          "timestamp" =>
            "2026-06-14T15:#{String.pad_leading(Integer.to_string(index), 2, "0")}:00Z"
        })
      end

    oldest_event = List.first(events)

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/issues")

    assert has_element?(view, "#load-more-issues")
    refute has_element?(view, "#issues-#{oldest_event.issue_id}")

    view
    |> element("#load-more-issues")
    |> render_click()

    assert has_element?(view, "#issues-#{oldest_event.issue_id}")
  end

  test "inserts new issues through PubSub", %{conn: conn} do
    project = project_fixture()
    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/issues")

    assert has_element?(view, "#issues-empty-state")

    event = event_fixture(project, "javascript.json")

    assert has_element?(view, "#issues-#{event.issue_id}")
  end

  test "shows issue details, updates status, and loads raw event JSON", %{conn: conn} do
    project = project_fixture()
    event = event_fixture(project, "javascript.json")

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/issues/#{event.issue_id}")

    assert has_element?(view, "#issue-status", "unresolved")
    assert has_element?(view, "#issue-event-#{event.id}")
    assert has_element?(view, "#load-raw-event-#{event.id}")

    view
    |> element("#set-status-resolved")
    |> render_click()

    assert has_element?(view, "#issue-status", "resolved")

    view
    |> element("#load-raw-event-#{event.id}")
    |> render_click()

    assert has_element?(view, "#raw-event-json")
  end

  test "project list links to issue triage", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "#project-issues-link-#{project.id}")
  end

  defp event_fixture(project, fixture, overrides \\ %{}) do
    payload =
      fixture
      |> fixture_payload()
      |> Map.merge(overrides)

    raw_event =
      %RawEvent{}
      |> RawEvent.changeset(%{
        project_id: project.id,
        event_id: payload["event_id"],
        source: "store",
        payload_type: "event",
        payload: payload,
        auth: %{"public_key" => project.public_key},
        received_at: ~U[2026-06-14 16:00:00.000000Z]
      })
      |> Repo.insert!()

    assert {:ok, event} = Events.normalize_raw_event(raw_event)
    event
  end

  defp fixture_payload(filename) do
    @fixtures
    |> Path.join(filename)
    |> File.read!()
    |> Jason.decode!()
  end

  defp project_fixture do
    assert {:ok, project} =
             Projects.create_project(%{"name" => unique_project_name()},
               dsn_base_url: "https://errors.example.com"
             )

    project
  end

  defp unique_project_name do
    "Project #{System.unique_integer([:positive])}"
  end
end
