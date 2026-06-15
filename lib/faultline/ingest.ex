defmodule Faultline.Ingest do
  @moduledoc """
  Accepts Sentry-compatible ingest payloads and stores raw events.
  """

  import Ecto.Query, warn: false

  alias Faultline.Ingest.RawEvent
  alias Faultline.Events
  alias Faultline.Projects.Project
  alias Faultline.Repo
  alias Faultline.Retention
  alias Faultline.Sentry.Auth

  @event_item_type "event"

  @doc """
  Finds and authorizes a project from request auth.
  """
  def authorize_project(project_id, conn) do
    with {:ok, project_number} <- parse_project_number(project_id),
         %Project{} = project <- Repo.get_by(Project, project_number: project_number),
         {:ok, auth} <- Auth.parse(conn),
         true <- Auth.authorized?(project, auth) do
      {:ok, project, auth}
    else
      nil -> {:error, :project_not_found}
      false -> {:error, :invalid_auth}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stores a raw event submitted to `/api/:project_id/store/`.
  """
  def accept_store(%Project{} = project, payload, auth) when is_map(payload) do
    event_id = event_id(payload) || random_event_id()

    cond do
      Retention.dropped_by_rule?(project, payload) ->
        {:ok, %{event_id: event_id, stored?: false}}

      not rate_limit_allows?(project, 1) ->
        {:error, :rate_limited}

      true ->
        create_raw_event(project, %{
          event_id: event_id,
          source: "store",
          payload_type: @event_item_type,
          payload: payload,
          auth: encode_auth(auth)
        })
    end
  end

  def accept_store(%Project{}, _payload, _auth), do: {:error, :invalid_payload}

  @doc """
  Stores event items from a Sentry envelope body.

  Unknown item types are intentionally accepted and ignored.
  """
  def accept_envelope(%Project{} = project, body, auth) when is_binary(body) do
    with {:ok, envelope_header, items} <- decode_envelope(body) do
      event_items = Enum.filter(items, &(&1.type == @event_item_type))

      if rate_limit_allows?(project, length(event_items)) do
        event_items
        |> Enum.reduce_while({:ok, []}, fn item, {:ok, raw_events} ->
          case create_envelope_event(project, envelope_header, item, auth) do
            {:ok, nil} -> {:cont, {:ok, raw_events}}
            {:ok, raw_event} -> {:cont, {:ok, [raw_event | raw_events]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
        |> case do
          {:ok, raw_events} -> {:ok, Enum.reverse(raw_events)}
          {:error, reason} -> {:error, reason}
        end
      else
        {:error, :rate_limited}
      end
    end
  end

  def accept_envelope(%Project{}, _body, _auth), do: {:error, :invalid_payload}

  defp create_envelope_event(project, envelope_header, item, auth) do
    with {:ok, payload} <- Jason.decode(item.payload),
         true <- is_map(payload) do
      event_id = event_id(payload) || event_id(envelope_header) || random_event_id()

      if Retention.dropped_by_rule?(project, payload) do
        {:ok, nil}
      else
        create_raw_event(project, %{
          event_id: event_id,
          source: "envelope",
          payload_type: @event_item_type,
          payload: payload,
          auth: encode_auth(auth)
        })
      end
    else
      _ -> {:error, :invalid_payload}
    end
  end

  defp rate_limit_allows?(_project, event_count) when event_count <= 0, do: true

  defp rate_limit_allows?(project, event_count) do
    window_start = DateTime.add(DateTime.utc_now(), -project.rate_limit_window_seconds, :second)

    recent_count =
      RawEvent
      |> where([raw_event], raw_event.project_id == ^project.id)
      |> where([raw_event], raw_event.received_at >= ^window_start)
      |> Repo.aggregate(:count)

    recent_count + event_count <= project.rate_limit_max_events
  end

  defp create_raw_event(project, attrs) do
    attrs =
      attrs
      |> Map.put(:project_id, project.id)
      |> Map.put_new(:received_at, DateTime.utc_now())

    %RawEvent{}
    |> RawEvent.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, raw_event} ->
        case Events.normalize_raw_event(raw_event) do
          {:ok, _event} -> {:ok, raw_event}
          {:error, changeset} -> {:error, changeset}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp decode_envelope(body) do
    with {:ok, header_line, rest} <- take_line(body),
         {:ok, header} <- Jason.decode(header_line),
         true <- is_map(header),
         {:ok, items} <- decode_items(rest, []) do
      {:ok, header, items}
    else
      _ -> {:error, :invalid_payload}
    end
  end

  defp decode_items("", items), do: {:ok, Enum.reverse(items)}

  defp decode_items("\n" <> rest, items), do: decode_items(rest, items)

  defp decode_items(body, items) do
    with {:ok, header_line, rest} <- take_line(body),
         {:ok, header} <- Jason.decode(header_line),
         true <- is_map(header),
         {:ok, payload, rest} <- take_payload(rest, header) do
      item = %{type: Map.get(header, "type"), payload: payload}
      decode_items(rest, [item | items])
    else
      _ -> {:error, :invalid_payload}
    end
  end

  defp take_line(body) do
    case :binary.match(body, "\n") do
      {index, 1} ->
        <<line::binary-size(index), "\n", rest::binary>> = body
        {:ok, String.trim_trailing(line, "\r"), rest}

      :nomatch ->
        if body == "", do: :error, else: {:ok, String.trim_trailing(body, "\r"), ""}
    end
  end

  defp take_payload(body, %{"length" => length}) when is_integer(length) and length >= 0 do
    if byte_size(body) >= length do
      <<payload::binary-size(length), rest::binary>> = body
      {:ok, payload, trim_one_newline(rest)}
    else
      :error
    end
  end

  defp take_payload(body, _header), do: take_line(body)

  defp trim_one_newline("\r\n" <> rest), do: rest
  defp trim_one_newline("\n" <> rest), do: rest
  defp trim_one_newline(rest), do: rest

  defp event_id(%{"event_id" => event_id}) when is_binary(event_id) and event_id != "",
    do: event_id

  defp event_id(_payload), do: nil

  defp encode_auth(auth) do
    auth
    |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)
    |> Map.new()
  end

  defp parse_project_number(project_id) when is_binary(project_id) do
    case Integer.parse(project_id) do
      {project_number, ""} when project_number > 0 -> {:ok, project_number}
      _ -> {:error, :project_not_found}
    end
  end

  defp random_event_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
