defmodule Faultline.Events.Normalizer do
  @moduledoc """
  Converts raw Sentry event payloads into Faultline's stable event shape.
  """

  alias Faultline.Ingest.RawEvent

  @spec normalize(RawEvent.t()) :: map()
  def normalize(%RawEvent{} = raw_event) do
    payload = raw_event.payload || %{}
    exception = first_exception(payload)
    request = map_value(payload, "request")
    user = map_value(payload, "user")

    %{
      event_id: text_value(payload, "event_id") || raw_event.event_id,
      occurred_at: occurred_at(payload, raw_event),
      platform: text_value(payload, "platform"),
      logger: text_value(payload, "logger"),
      level: text_value(payload, "level"),
      culprit: text_value(payload, "culprit"),
      message: message(payload, exception),
      exception_type: text_value(exception, "type"),
      exception_value: text_value(exception, "value"),
      release: text_value(payload, "release"),
      environment: text_value(payload, "environment"),
      server_name: text_value(payload, "server_name"),
      user_identifier: user_identifier(user),
      request_url: text_value(request, "url"),
      details: details(payload, exception, user, request),
      project_id: raw_event.project_id,
      raw_event_id: raw_event.id
    }
  end

  defp occurred_at(payload, raw_event) do
    payload
    |> Map.get("timestamp")
    |> parse_timestamp()
    |> case do
      {:ok, datetime} -> datetime
      :error -> raw_event.received_at || DateTime.utc_now()
    end
  end

  defp parse_timestamp(%DateTime{} = datetime), do: {:ok, datetime}

  defp parse_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix(timestamp)
  end

  defp parse_timestamp(timestamp) when is_float(timestamp) do
    timestamp
    |> Kernel.*(1_000_000)
    |> round()
    |> DateTime.from_unix(:microsecond)
  end

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> :error
    end
  end

  defp parse_timestamp(_timestamp), do: :error

  defp message(payload, exception) do
    text_value(payload, "message") ||
      get_in(payload, ["logentry", "formatted"]) ||
      get_in(payload, ["logentry", "message"]) ||
      text_value(exception, "value")
  end

  defp first_exception(%{"exception" => %{"values" => values}}) when is_list(values) do
    Enum.find(values, &is_map/1) || %{}
  end

  defp first_exception(_payload), do: %{}

  defp details(payload, exception, user, request) do
    %{
      "breadcrumbs" => breadcrumbs(payload),
      "contexts" => map_value(payload, "contexts"),
      "exception" => %{
        "mechanism" => map_value(exception, "mechanism"),
        "stacktrace_frames" => stacktrace_frames(exception)
      },
      "request" => request,
      "tags" => tags(payload),
      "user" => user
    }
  end

  defp stacktrace_frames(%{"stacktrace" => %{"frames" => frames}}) when is_list(frames),
    do: frames

  defp stacktrace_frames(_exception), do: []

  defp breadcrumbs(%{"breadcrumbs" => %{"values" => values}}) when is_list(values), do: values
  defp breadcrumbs(_payload), do: []

  defp tags(%{"tags" => tags}) when is_map(tags), do: tags

  defp tags(%{"tags" => tags}) when is_list(tags) do
    tags
    |> Enum.reduce(%{}, fn
      {key, value}, acc -> Map.put(acc, to_string(key), value)
      [key, value], acc -> Map.put(acc, to_string(key), value)
      _tag, acc -> acc
    end)
  end

  defp tags(_payload), do: %{}

  defp user_identifier(user) do
    text_value(user, "id") ||
      text_value(user, "email") ||
      text_value(user, "username") ||
      text_value(user, "ip_address")
  end

  defp map_value(map, key) when is_map(map) do
    case Map.get(map, key) do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  defp map_value(_map, _key), do: %{}

  defp text_value(map, key) when is_map(map) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> value
      value when is_integer(value) -> Integer.to_string(value)
      value when is_float(value) -> Float.to_string(value)
      _ -> nil
    end
  end

  defp text_value(_map, _key), do: nil
end
