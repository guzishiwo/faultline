defmodule FaultlineWeb.IssueLiveTest do
  use FaultlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Faultline.Events
  alias Faultline.Ingest.RawEvent
  alias Faultline.Projects
  alias Faultline.Repo

  @fixtures Path.expand("../../fixtures/sentry_events", __DIR__)

  setup :register_and_log_in_user

  test "lists project issues and links to details", %{conn: conn} do
    project = project_fixture()
    event = event_fixture(project, "javascript.json")

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues")

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
            "2026-06-14T15:#{String.pad_leading(Integer.to_string(index), 2, "0")}:00Z",
          "exception" => distinct_exception(index)
        })
      end

    oldest_event = List.first(events)

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues")

    assert has_element?(view, "#load-more-issues")
    refute has_element?(view, "#issues-#{oldest_event.issue_id}")

    view
    |> element("#load-more-issues")
    |> render_click()

    assert has_element?(view, "#issues-#{oldest_event.issue_id}")
  end

  test "inserts new issues through PubSub", %{conn: conn} do
    project = project_fixture()
    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues")

    assert has_element?(view, "#issues-empty-state")

    event = event_fixture(project, "javascript.json")

    assert has_element?(view, "#issues-#{event.issue_id}")
  end

  test "shows issue details, updates status, and loads raw event JSON", %{conn: conn} do
    project = project_fixture()

    older_event =
      event_fixture(project, "javascript.json", %{
        "timestamp" => "2026-06-14T15:00:00Z",
        "release" => "web@1.2.3"
      })

    newer_event =
      event_fixture(project, "javascript.json", %{
        "event_id" => "99999999999999999999999999999999",
        "timestamp" => "2026-06-14T15:05:00Z",
        "release" => "web@2.0.0",
        "contexts" => smoke_contexts(),
        "sdk" => smoke_sdk(),
        "modules" => %{"@sentry/node" => "^10.57.0"}
      })

    newer_event
    |> Ecto.Changeset.change(details: Map.drop(newer_event.details, ~w(contexts modules sdk)))
    |> Repo.update!()

    {:ok, view, _html} = live(conn, ~p"/p/#{project.slug}/issues/#{older_event.issue_id}")

    assert has_element?(view, "#issue-status", "unresolved")
    assert has_element?(view, "#issue-occurrences")
    assert has_element?(view, "#select-event-#{older_event.id}")
    assert has_element?(view, "#select-event-#{newer_event.id}")

    view
    |> element("#select-event-#{newer_event.id}")
    |> render_click()

    assert has_element?(view, "#issue-event-#{newer_event.id}")
    assert has_element?(view, "#stack-frame-1")
    assert has_element?(view, "#event-overview")
    assert has_element?(view, "#event-context")
    assert has_element?(view, "#event-sdk")
    assert has_element?(view, "#event-context-runtime", "node")
    assert has_element?(view, "#event-context-device", "Apple M3 Pro")
    assert has_element?(view, "#event-context-trace", "ab08bb5f21f04795ad26d8d3f919379d")
    assert has_element?(view, "#event-modules", "@sentry/node")
    assert has_element?(view, "#event-sdk", "sentry.javascript.node")
    assert has_element?(view, "#load-raw-event-#{newer_event.id}")

    view
    |> element("#set-status-resolved")
    |> render_click()

    assert has_element?(view, "#issue-status", "resolved")

    view
    |> element("#select-event-#{older_event.id}")
    |> render_click()

    assert has_element?(view, "#issue-event-#{older_event.id}")
    assert has_element?(view, "#issue-event-#{older_event.id}", "web@1.2.3")

    view
    |> element("#load-raw-event-#{older_event.id}")
    |> render_click()

    assert has_element?(view, "#raw-event-json")
    assert has_element?(view, "#raw-event-json .json-key")
    assert has_element?(view, "#raw-event-json .json-string")

    view
    |> element("#select-event-#{newer_event.id}")
    |> render_click()

    assert has_element?(view, "#issue-event-#{newer_event.id}")
    refute has_element?(view, "#raw-event-json")
  end

  test "project list links to issue triage", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects")

    assert has_element?(view, "#project-issues-link-#{project.id}")
    assert has_element?(view, "#project-settings-link-#{project.id}")
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

  defp distinct_exception(index) do
    %{
      "values" => [
        %{
          "type" => "TypeError",
          "value" => "Cannot read properties of undefined",
          "stacktrace" => %{
            "frames" => [
              %{
                "filename" => "assets/js/checkout_#{index}.js",
                "function" => "submitOrder#{index}",
                "lineno" => 42,
                "in_app" => true
              }
            ]
          }
        }
      ]
    }
  end

  defp smoke_contexts do
    %{
      "device" => %{
        "arch" => "arm64",
        "cpu_description" => "Apple M3 Pro",
        "processor_count" => 11
      },
      "runtime" => %{"name" => "node", "version" => "v25.8.2"},
      "trace" => %{
        "trace_id" => "ab08bb5f21f04795ad26d8d3f919379d",
        "span_id" => "b1ecefa84c94387a"
      }
    }
  end

  defp smoke_sdk do
    %{
      "name" => "sentry.javascript.node",
      "version" => "10.57.0",
      "packages" => [%{"name" => "npm:@sentry/node", "version" => "10.57.0"}],
      "integrations" => ["InboundFilters", "NodeFetch", "Express"]
    }
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
