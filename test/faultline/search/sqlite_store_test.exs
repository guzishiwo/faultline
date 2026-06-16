defmodule Faultline.Search.SQLiteStoreTest do
  use Faultline.DataCase, async: true

  alias Faultline.Events
  alias Faultline.Ingest.RawEvent
  alias Faultline.Projects
  alias Faultline.Repo
  alias Faultline.Search

  @fixtures Path.expand("../../fixtures/sentry_events", __DIR__)

  test "syncs event tags and issue tag rollups during ingest" do
    project = project_fixture()

    first =
      "javascript.json"
      |> fixture_payload()
      |> Map.put("release", "web@1.2.3")
      |> Map.put("environment", "production")
      |> Map.put("tags", %{"feature" => "checkout flow", "trace" => "abc123"})
      |> put_in(["user", "id"], "user-1")
      |> normalize_payload(project)

    second =
      "javascript.json"
      |> fixture_payload()
      |> Map.put("event_id", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
      |> Map.put("release", "web@1.2.3")
      |> Map.put("environment", "production")
      |> Map.put("tags", %{"feature" => "checkout flow", "trace" => "abc123"})
      |> put_in(["user", "id"], "user-2")
      |> normalize_payload(project)

    assert first.issue_id == second.issue_id

    assert tag_count("event_tag_values", first.issue_id, "release", "web@1.2.3") == 2

    [rollup] =
      Repo.query!(
        """
        SELECT event_count, first_seen_at, last_seen_at
        FROM issue_tag_values
        WHERE issue_id = ? AND key = ? AND value = ?
        """,
        [first.issue_id, "feature", "checkout flow"]
      ).rows

    assert [2, _first_seen, _last_seen] = rollup
  end

  test "searches issues by tag filters and FTS text terms" do
    project = project_fixture()

    target =
      "javascript.json"
      |> fixture_payload()
      |> Map.put("release", "web@1.2.3")
      |> Map.put("environment", "production")
      |> Map.put("tags", %{"feature" => "checkout flow"})
      |> put_in(["exception", "values", Access.at(0), "value"], "Checkout payment failed")
      |> normalize_payload(project)

    _other =
      "ruby.json"
      |> fixture_payload()
      |> Map.put("release", "worker@9.9.9")
      |> Map.put("environment", "staging")
      |> Map.put("tags", %{"feature" => "background job"})
      |> normalize_payload(project)

    assert [target.issue_id] ==
             "release:web@1.2.3 environment:production Checkout"
             |> Search.search_issues(project_id: project.id)
             |> Enum.sort()

    assert [] =
             Search.search_issues("release:web@1.2.3 environment:staging Checkout",
               project_id: project.id
             )
  end

  test "searches events inside an issue by tag filters" do
    project = project_fixture()

    first =
      "javascript.json"
      |> fixture_payload()
      |> Map.put("release", "web@1.2.3")
      |> put_in(["user", "id"], "user-1")
      |> normalize_payload(project)

    second =
      "javascript.json"
      |> fixture_payload()
      |> Map.put("event_id", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
      |> Map.put("release", "web@2.0.0")
      |> put_in(["user", "id"], "user-2")
      |> normalize_payload(project)

    assert first.issue_id == second.issue_id

    assert [second.id] == Search.search_events("release:web@2.0.0", first.issue_id)
    assert [first.id] == Search.search_events("user:user-1", first.issue_id)
  end

  defp tag_count(table, issue_id, key, value) do
    Repo.query!(
      "SELECT COUNT(*) FROM #{table} WHERE issue_id = ? AND key = ? AND value = ?",
      [issue_id, key, value]
    ).rows
    |> List.first()
    |> List.first()
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
