defmodule FaultlineWeb.IngestController do
  use FaultlineWeb, :controller

  alias Faultline.Ingest

  def store(conn, %{"project_id" => project_id}) do
    with {:ok, project, auth} <- Ingest.authorize_project(project_id, conn),
         {:ok, raw_event} <- Ingest.accept_store(project, conn.body_params, auth) do
      json(conn, %{id: raw_event.event_id})
    else
      error -> error_response(conn, error)
    end
  end

  def envelope(conn, %{"project_id" => project_id}) do
    with {:ok, project, auth} <- Ingest.authorize_project(project_id, conn),
         {:ok, body, conn} <- read_full_body(conn),
         {:ok, _raw_events} <- Ingest.accept_envelope(project, body, auth) do
      json(conn, %{})
    else
      error -> error_response(conn, error)
    end
  end

  defp error_response(conn, {:error, :project_not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{detail: "Project not found"}})
  end

  defp error_response(conn, {:error, reason}) when reason in [:missing_auth, :invalid_auth] do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: "Invalid Sentry authentication"}})
  end

  defp error_response(conn, {:error, :invalid_payload}) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "Invalid Sentry payload"}})
  end

  defp read_full_body(conn, acc \\ "") do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} -> {:ok, acc <> body, conn}
      {:more, body, conn} -> read_full_body(conn, acc <> body)
      {:error, _reason} -> {:error, :invalid_payload}
    end
  end
end
