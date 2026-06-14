defmodule Faultline.IssuesTest do
  use Faultline.DataCase, async: true

  alias Faultline.Events
  alias Faultline.Ingest.RawEvent
  alias Faultline.Issues
  alias Faultline.Issues.Grouping
  alias Faultline.Issues.Issue
  alias Faultline.Projects
  alias Faultline.Repo

  @fixtures Path.expand("../fixtures/sentry_events", __DIR__)

  describe "grouping fingerprints" do
    test "groups repeated events by exception type, stacktrace, platform, and culprit" do
      project = project_fixture()

      first =
        "javascript.json"
        |> fixture_payload()
        |> Map.put("message", "first customer-facing message")
        |> put_in(["user", "id"], "user-1")
        |> normalize_payload(project)

      second =
        "javascript.json"
        |> fixture_payload()
        |> Map.put("event_id", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
        |> Map.put("message", "second customer-facing message")
        |> put_in(["user", "id"], "user-2")
        |> normalize_payload(project)

      assert first.issue_id == second.issue_id
      assert Grouping.fingerprint(first) == Grouping.fingerprint(second)

      issue = Repo.get!(Issue, first.issue_id)
      assert issue.event_count == 2
      assert issue.affected_user_count == 2
    end

    test "uses explicit SDK fingerprint when present" do
      project = project_fixture()

      first =
        "javascript.json"
        |> fixture_payload()
        |> Map.put("fingerprint", ["checkout", "payment-decline"])
        |> normalize_payload(project)

      second =
        "ruby.json"
        |> fixture_payload()
        |> Map.put("fingerprint", ["checkout", "payment-decline"])
        |> normalize_payload(project)

      assert first.issue_id == second.issue_id
      assert Grouping.fingerprint(first) == Grouping.fingerprint(second)
    end

    test "ignores explicit default fingerprint and falls back to default grouping" do
      project = project_fixture()

      default_fingerprint_event =
        "javascript.json"
        |> fixture_payload()
        |> Map.put("fingerprint", ["{{ default }}"])
        |> normalize_payload(project)

      plain_event =
        "javascript.json"
        |> fixture_payload()
        |> Map.delete("fingerprint")
        |> Map.put("event_id", "ffffffffffffffffffffffffffffffff")
        |> normalize_payload(project)

      assert Grouping.fingerprint(default_fingerprint_event) == Grouping.fingerprint(plain_event)
      assert default_fingerprint_event.issue_id == plain_event.issue_id
    end
  end

  describe "issue lifecycle" do
    test "tracks first seen, last seen, count, affected users, and status" do
      project = project_fixture()

      first =
        "javascript.json"
        |> fixture_payload()
        |> Map.put("timestamp", "2026-06-14T15:00:00Z")
        |> put_in(["user", "id"], "user-1")
        |> normalize_payload(project)

      second =
        "javascript.json"
        |> fixture_payload()
        |> Map.put("event_id", "12121212121212121212121212121212")
        |> Map.put("timestamp", "2026-06-14T15:05:00Z")
        |> put_in(["user", "id"], "user-1")
        |> normalize_payload(project)

      third =
        "javascript.json"
        |> fixture_payload()
        |> Map.put("event_id", "34343434343434343434343434343434")
        |> Map.put("timestamp", "2026-06-14T14:55:00Z")
        |> put_in(["user", "id"], "user-2")
        |> normalize_payload(project)

      assert first.issue_id == second.issue_id
      assert second.issue_id == third.issue_id

      issue = Repo.get!(Issue, first.issue_id)
      assert issue.status == "unresolved"
      assert issue.event_count == 3
      assert issue.affected_user_count == 2
      assert issue.first_seen_at == ~U[2026-06-14 14:55:00.000000Z]
      assert issue.last_seen_at == ~U[2026-06-14 15:05:00.000000Z]
    end

    test "reopens resolved issues when a new matching event arrives" do
      project = project_fixture()

      first =
        "javascript.json"
        |> fixture_payload()
        |> normalize_payload(project)

      issue = Repo.get!(Issue, first.issue_id)
      assert {:ok, resolved_issue} = Issues.update_issue_status(issue, "resolved")

      "javascript.json"
      |> fixture_payload()
      |> Map.put("event_id", "56565656565656565656565656565656")
      |> normalize_payload(project)

      reopened_issue = Repo.get!(Issue, resolved_issue.id)
      assert reopened_issue.status == "unresolved"
      assert reopened_issue.event_count == 2
    end

    test "lists project issues newest first" do
      project = project_fixture()

      older =
        "javascript.json"
        |> fixture_payload()
        |> Map.put("timestamp", "2026-06-14T15:00:00Z")
        |> normalize_payload(project)

      newer =
        "ruby.json"
        |> fixture_payload()
        |> Map.put("timestamp", "2026-06-14T16:00:00Z")
        |> normalize_payload(project)

      older_issue = Repo.get!(Issue, older.issue_id)
      newer_issue = Repo.get!(Issue, newer.issue_id)

      assert [^newer_issue, ^older_issue] = Issues.list_project_issues(project.id)
    end
  end

  defp normalize_payload(payload, project) do
    raw_event =
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
