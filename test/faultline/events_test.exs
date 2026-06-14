defmodule Faultline.EventsTest do
  use Faultline.DataCase, async: true

  alias Faultline.Events
  alias Faultline.Events.Event
  alias Faultline.Ingest
  alias Faultline.Ingest.RawEvent
  alias Faultline.Projects
  alias Faultline.Repo

  @fixtures Path.expand("../fixtures/sentry_events", __DIR__)

  describe "normalize_raw_event/1" do
    test "extracts queryable fields and JSON details from a JavaScript event" do
      raw_event = raw_event_fixture("javascript.json")

      assert {:ok, event} = Events.normalize_raw_event(raw_event)

      assert event.event_id == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      assert event.occurred_at == ~U[2026-06-14 15:00:00.000000Z]
      assert event.platform == "javascript"
      assert event.logger == "console"
      assert event.level == "error"
      assert event.culprit == "checkout.submit"
      assert event.message == "TypeError: Cannot read properties of undefined"
      assert event.exception_type == "TypeError"
      assert event.exception_value == "Cannot read properties of undefined"
      assert event.release == "web@1.2.3"
      assert event.environment == "production"
      assert event.server_name == "web-1"
      assert event.user_identifier == "user-123"
      assert event.request_url == "https://example.com/checkout"
      assert event.details["tags"] == %{"browser" => "Chrome", "region" => "iad"}
      assert [%{"function" => "submitOrder"}] = event.details["exception"]["stacktrace_frames"]
      assert [%{"message" => "Submit order"}] = event.details["breadcrumbs"]
    end

    test "supports Python numeric timestamps and list tags" do
      raw_event = raw_event_fixture("python.json")

      assert {:ok, event} = Events.normalize_raw_event(raw_event)

      assert event.platform == "python"
      assert event.level == "warning"
      assert event.user_identifier == "ops-user"
      assert event.details["tags"] == %{"queue" => "critical", "tenant" => "acme"}
      assert event.occurred_at == ~U[2026-06-14 15:01:01.123456Z]
    end

    test "supports Ruby exception events" do
      raw_event = raw_event_fixture("ruby.json")

      assert {:ok, event} = Events.normalize_raw_event(raw_event)

      assert event.platform == "ruby"
      assert event.exception_type == "ActiveRecord::RecordInvalid"
      assert event.exception_value == "Validation failed"
      assert event.user_identifier == "203.0.113.10"

      assert [%{"filename" => "app/controllers/orders_controller.rb"}] =
               event.details["exception"]["stacktrace_frames"]
    end

    test "accepts malformed but usable payloads by falling back to raw metadata" do
      raw_event = raw_event_fixture("elixir.json")

      assert {:ok, event} = Events.normalize_raw_event(raw_event)

      assert event.event_id == "dddddddddddddddddddddddddddddddd"
      assert event.occurred_at == raw_event.received_at
      assert event.platform == "elixir"
      assert event.message == "boom"
      assert event.exception_type == "RuntimeError"
    end
  end

  describe "ingest integration" do
    test "creates a normalized event when accepting a raw store payload" do
      project = project_fixture()
      payload = fixture_payload("javascript.json")

      assert {:ok, raw_event} =
               Ingest.accept_store(project, payload, %{public_key: project.public_key})

      event = Repo.one!(Event)
      assert event.raw_event_id == raw_event.id
      assert event.project_id == project.id
      assert event.event_id == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    end

    test "lists project events newest first" do
      first = raw_event_fixture("javascript.json")
      second = raw_event_fixture("ruby.json", project: first.project)

      assert {:ok, first_event} = Events.normalize_raw_event(first)
      assert {:ok, second_event} = Events.normalize_raw_event(second)

      assert [^second_event, ^first_event] = Events.list_project_events(first.project_id)
    end
  end

  defp raw_event_fixture(filename, opts \\ []) do
    project = Keyword.get_lazy(opts, :project, &project_fixture/0)
    payload = fixture_payload(filename)

    %RawEvent{}
    |> RawEvent.changeset(%{
      project_id: project.id,
      event_id: payload["event_id"] || "raw-event-id",
      source: "store",
      payload_type: "event",
      payload: payload,
      auth: %{"public_key" => project.public_key},
      received_at: ~U[2026-06-14 16:00:00.000000Z]
    })
    |> Repo.insert!()
    |> Repo.preload(:project)
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
