defmodule Faultline.RetentionTest do
  use Faultline.DataCase, async: true

  alias Faultline.Events
  alias Faultline.Ingest.RawEvent
  alias Faultline.Issues.Issue
  alias Faultline.Projects
  alias Faultline.Repo
  alias Faultline.Retention
  alias Faultline.Retention.CleanupWorker

  describe "drop rules" do
    test "matches enabled rules against normalized noisy event fields" do
      project = project_fixture()

      assert {:ok, _rule} =
               Retention.create_drop_rule(project, %{
                 "name" => "Drop timeouts",
                 "enabled" => true,
                 "match_field" => "exception_type",
                 "match_type" => "contains",
                 "match_value" => "timeout"
               })

      assert Retention.dropped_by_rule?(project, %{
               "exception" => %{"values" => [%{"type" => "TimeoutError"}]}
             })

      refute Retention.dropped_by_rule?(project, %{
               "exception" => %{"values" => [%{"type" => "RuntimeError"}]}
             })
    end
  end

  describe "cleanup_project/2" do
    test "removes raw events past retention days and refreshes issue counters" do
      project = project_fixture(%{"retention_days" => "7", "retention_event_limit" => "100"})
      stale = raw_event_fixture(project, "stale", ~U[2026-06-01 00:00:00.000000Z])
      fresh = raw_event_fixture(project, "fresh", ~U[2026-06-10 00:00:00.000000Z])

      assert {:ok, stale_event} = Events.normalize_raw_event(stale)
      assert {:ok, fresh_event} = Events.normalize_raw_event(fresh)
      assert stale_event.issue_id == fresh_event.issue_id

      result = Retention.cleanup_project(project, ~U[2026-06-15 00:00:00.000000Z])

      assert result.raw_events_deleted == 1
      refute Repo.get(RawEvent, stale.id)
      assert Repo.get!(RawEvent, fresh.id)

      issue = Repo.get!(Issue, fresh_event.issue_id)
      assert issue.event_count == 1
      assert issue.first_seen_at == fresh_event.occurred_at
      assert issue.last_seen_at == fresh_event.occurred_at
    end

    test "keeps only the newest raw events above the per-project cap" do
      project = project_fixture(%{"retention_days" => "365", "retention_event_limit" => "2"})

      older = raw_event_fixture(project, "older", ~U[2026-06-01 00:00:00.000000Z])
      middle = raw_event_fixture(project, "middle", ~U[2026-06-02 00:00:00.000000Z])
      newer = raw_event_fixture(project, "newer", ~U[2026-06-03 00:00:00.000000Z])

      assert {:ok, _event} = Events.normalize_raw_event(older)
      assert {:ok, _event} = Events.normalize_raw_event(middle)
      assert {:ok, _event} = Events.normalize_raw_event(newer)

      result = Retention.cleanup_project(project, ~U[2026-06-15 00:00:00.000000Z])

      assert result.raw_events_deleted == 1
      refute Repo.get(RawEvent, older.id)
      assert Repo.get!(RawEvent, middle.id)
      assert Repo.get!(RawEvent, newer.id)
    end
  end

  describe "cleanup worker" do
    test "runs retention cleanup on the local node" do
      project = project_fixture(%{"retention_days" => "7", "retention_event_limit" => "100"})
      stale = raw_event_fixture(project, "worker-stale", ~U[2026-06-01 00:00:00.000000Z])
      assert {:ok, _event} = Events.normalize_raw_event(stale)

      pid = start_supervised!({CleanupWorker, interval_ms: 3_600_000})
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      send(pid, :cleanup)
      _state = :sys.get_state(pid)

      refute Repo.get(RawEvent, stale.id)
    end
  end

  defp project_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          "name" => "Retention #{System.unique_integer([:positive])}",
          "rate_limit_max_events" => "1000",
          "rate_limit_window_seconds" => "60"
        },
        attrs
      )

    assert {:ok, project} =
             Projects.create_project(attrs, dsn_base_url: "https://errors.example.com")

    project
  end

  defp raw_event_fixture(project, event_id, received_at) do
    %RawEvent{}
    |> RawEvent.changeset(%{
      project_id: project.id,
      event_id: event_id,
      source: "store",
      payload_type: "event",
      payload: payload(event_id, received_at),
      auth: %{"public_key" => project.public_key},
      received_at: received_at
    })
    |> Repo.insert!()
  end

  defp payload(event_id, timestamp) do
    %{
      "event_id" => event_id,
      "timestamp" => DateTime.to_iso8601(timestamp),
      "platform" => "elixir",
      "level" => "error",
      "message" => "same grouped error",
      "exception" => %{
        "values" => [
          %{
            "type" => "RuntimeError",
            "value" => "same grouped error",
            "stacktrace" => %{
              "frames" => [
                %{"filename" => "lib/app.ex", "function" => "run", "lineno" => 10}
              ]
            }
          }
        ]
      }
    }
  end
end
