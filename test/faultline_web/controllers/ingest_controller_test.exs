defmodule FaultlineWeb.IngestControllerTest do
  use FaultlineWeb.ConnCase, async: true

  alias Faultline.Ingest.RawEvent
  alias Faultline.Projects
  alias Faultline.Repo

  @fixtures Path.expand("fixtures", __DIR__)

  test "POST /api/:project_id/store/ accepts Sentry auth header and persists a raw event", %{
    conn: conn
  } do
    project = project_fixture("Store service")
    body = File.read!(Path.join(@fixtures, "store_event.json"))

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-sentry-auth", sentry_auth_header(project))
      |> post(~p"/api/#{project.id}/store/", body)

    assert %{"id" => "11111111111111111111111111111111"} = json_response(conn, 200)

    raw_event = Repo.one!(RawEvent)
    assert raw_event.project_id == project.id
    assert raw_event.source == "store"
    assert raw_event.payload_type == "event"
    assert raw_event.payload["message"] == "Captured fixture exception"
    assert raw_event.auth["public_key"] == project.public_key
  end

  test "POST /api/:project_id/envelope/ accepts query auth, stores event items, and ignores unknown items",
       %{conn: conn} do
    project = project_fixture("Envelope service")
    body = File.read!(Path.join(@fixtures, "envelope_event.txt"))

    conn =
      conn
      |> put_req_header("content-type", "application/x-sentry-envelope")
      |> post(
        ~p"/api/#{project.id}/envelope/?sentry_key=#{project.public_key}&sentry_secret=#{project.secret_key}&sentry_version=7",
        body
      )

    assert json_response(conn, 200) == %{}

    raw_event = Repo.one!(RawEvent)
    assert raw_event.project_id == project.id
    assert raw_event.event_id == "22222222222222222222222222222222"
    assert raw_event.source == "envelope"
    assert raw_event.payload["message"] == "Envelope fixture exception"
  end

  test "rejects invalid auth", %{conn: conn} do
    project = project_fixture("Auth service")
    body = File.read!(Path.join(@fixtures, "store_event.json"))

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header(
        "x-sentry-auth",
        "Sentry sentry_version=7, sentry_key=wrong, sentry_secret=#{project.secret_key}"
      )
      |> post(~p"/api/#{project.id}/store/", body)

    assert %{"errors" => %{"detail" => "Invalid Sentry authentication"}} =
             json_response(conn, 401)

    assert Repo.aggregate(RawEvent, :count) == 0
  end

  test "rejects malformed envelopes", %{conn: conn} do
    project = project_fixture("Malformed envelope service")

    conn =
      conn
      |> put_req_header("content-type", "application/x-sentry-envelope")
      |> put_req_header("x-sentry-auth", sentry_auth_header(project))
      |> post(~p"/api/#{project.id}/envelope/", "not-json\n")

    assert %{"errors" => %{"detail" => "Invalid Sentry payload"}} = json_response(conn, 400)
    assert Repo.aggregate(RawEvent, :count) == 0
  end

  defp project_fixture(name) do
    assert {:ok, project} =
             Projects.create_project(%{"name" => name},
               dsn_base_url: "https://errors.example.com"
             )

    project
  end

  defp sentry_auth_header(project) do
    "Sentry sentry_version=7, sentry_client=faultline-test/1.0, sentry_key=#{project.public_key}, sentry_secret=#{project.secret_key}"
  end
end
