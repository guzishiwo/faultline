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
    frames =
      event
      |> stacktrace_frames()
      |> Enum.map(&frame_signature/1)

    hash([
      "default",
      event.platform,
      event.culprit,
      event.exception_type,
      frames
    ])
  end

  defp stacktrace_frames(event) do
    get_in(event.details, ["exception", "stacktrace_frames"]) || []
  end

  defp frame_signature(frame) when is_map(frame) do
    [
      Map.get(frame, "module"),
      Map.get(frame, "function"),
      Map.get(frame, "filename") || Map.get(frame, "abs_path"),
      Map.get(frame, "lineno")
    ]
  end

  defp frame_signature(frame), do: frame

  defp hash(values) do
    values
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp present?(value), do: is_binary(value) and value != ""
end
