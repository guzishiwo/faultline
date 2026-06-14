defmodule Faultline.Issues.Grouping do
  @moduledoc """
  Builds stable issue grouping fingerprints for normalized events.
  """

  alias Faultline.Events.Event

  @default_fingerprint "{{ default }}"

  @spec fingerprint(Event.t()) :: String.t()
  def fingerprint(%Event{} = event) do
    event
    |> sdk_fingerprint()
    |> case do
      [] -> default_fingerprint(event)
      values -> hash(["sdk" | values])
    end
  end

  @spec title(Event.t()) :: String.t()
  def title(%Event{} = event) do
    cond do
      present?(event.exception_type) and present?(event.exception_value) ->
        "#{event.exception_type}: #{event.exception_value}"

      present?(event.exception_type) ->
        event.exception_type

      present?(event.message) ->
        event.message

      true ->
        "Unknown event"
    end
  end

  defp sdk_fingerprint(event) do
    event.details
    |> Map.get("fingerprint", [])
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 in ["", @default_fingerprint]))
  end

  defp default_fingerprint(event) do
    case grouping_frame(event) do
      nil ->
        hash([
          "default-v2",
          "message",
          event.platform,
          event.exception_type,
          normalize_message(event.message)
        ])

      frame ->
        hash([
          "default-v2",
          "stacktrace",
          event.platform,
          event.exception_type,
          frame_function(frame),
          frame_path(frame)
        ])
    end
  end

  defp stacktrace_frames(event) do
    get_in(event.details, ["exception", "stacktrace_frames"]) || []
  end

  defp grouping_frame(event) do
    frames =
      event
      |> stacktrace_frames()
      |> Enum.filter(&is_map/1)
      |> Enum.reverse()

    Enum.find(frames, &(&1["in_app"] == true)) ||
      Enum.find(frames, &(not runtime_frame?(&1))) ||
      List.first(frames)
  end

  defp runtime_frame?(frame) do
    path = frame_path(frame)

    path == nil or
      String.starts_with?(path, "node:internal/") or
      String.contains?(path, "/node_modules/@sentry/") or
      String.contains?(path, "/node_modules/@opentelemetry/")
  end

  defp frame_function(frame) do
    frame
    |> Map.get("function", Map.get(frame, "module"))
    |> normalize_text()
  end

  defp frame_path(frame) do
    frame
    |> Map.get("filename", Map.get(frame, "abs_path"))
    |> normalize_path()
  end

  defp normalize_path(nil), do: nil

  defp normalize_path(path) do
    path =
      path
      |> to_string()
      |> String.trim()
      |> String.replace("\\", "/")
      |> String.split(["?", "#"], parts: 2)
      |> List.first()

    cond do
      path == "" ->
        nil

      String.starts_with?(path, "node:") ->
        path

      true ->
        path
        |> String.split("/", trim: true)
        |> Enum.take(-3)
        |> Enum.join("/")
    end
  end

  defp normalize_message(nil), do: nil

  defp normalize_message(message) do
    message
    |> normalize_text()
    |> String.replace(~r/"[^"]*"/, "\"?\"")
    |> String.replace(~r/'[^']*'/, "'?'")
    |> String.replace(~r/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i, "?")
    |> String.replace(~r/\b[0-9a-f]{16,}\b/i, "?")
    |> String.replace(~r/\b\d+\b/, "?")
  end

  defp normalize_text(nil), do: nil

  defp normalize_text(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp hash(values) do
    values
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp present?(value), do: is_binary(value) and value != ""
end
