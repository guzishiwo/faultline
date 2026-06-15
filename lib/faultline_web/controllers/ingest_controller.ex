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
         {:ok, body, conn} <- read_full_body(conn, max_envelope_bytes()),
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

  defp error_response(conn, {:error, :payload_too_large}) do
    conn
    |> put_status(413)
    |> json(%{errors: %{detail: "Sentry envelope is too large"}})
  end

  defp error_response(conn, {:error, :rate_limited}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{errors: %{detail: "Project ingest rate limit exceeded"}})
  end

  defp read_full_body(conn, max_bytes, acc \\ "") do
    bytes_left = max_bytes - byte_size(acc)

    if bytes_left < 0 do
      {:error, :payload_too_large}
    else
      read_length = min(bytes_left + 1, 1_000_000)

      case Plug.Conn.read_body(conn, length: bytes_left + 1, read_length: read_length) do
        {:ok, body, conn} -> append_body(conn, acc, body, max_bytes)
        {:more, body, conn} -> continue_body_read(conn, acc, body, max_bytes)
        {:error, _reason} -> {:error, :invalid_payload}
      end
    end
  end

  defp continue_body_read(conn, acc, body, max_bytes) do
    case append_body(conn, acc, body, max_bytes) do
      {:ok, acc, conn} -> read_full_body(conn, max_bytes, acc)
      {:error, reason} -> {:error, reason}
    end
  end

  defp append_body(conn, acc, body, max_bytes) do
    acc = acc <> body

    if byte_size(acc) > max_bytes do
      {:error, :payload_too_large}
    else
      {:ok, acc, conn}
    end
  end

  defp max_envelope_bytes do
    :faultline
    |> Application.get_env(:ingest, [])
    |> Keyword.fetch!(:max_envelope_bytes)
  end
end
