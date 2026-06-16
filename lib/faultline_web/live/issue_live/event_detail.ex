defmodule FaultlineWeb.IssueLive.EventDetail do
  @moduledoc false

  def occurrence_title(event) do
    compact_exception(event) || event.message || "Event"
  end

  def compact_exception(event) do
    [event.exception_type, event.exception_value]
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(": ")
    |> case do
      "" -> nil
      value -> value
    end
  end

  def mechanism_summary(event) do
    mechanism = get_in(event.details, ["exception", "mechanism"]) || %{}

    case {mechanism["type"], mechanism["handled"]} do
      {nil, nil} -> nil
      {type, nil} -> type
      {nil, handled} -> "handled=#{handled}"
      {type, handled} -> "#{type}, handled=#{handled}"
    end
  end

  def trace_summary(event) do
    trace = get_in(event.details, ["contexts", "trace"]) || %{}

    cond do
      is_binary(trace["trace_id"]) and is_binary(trace["span_id"]) ->
        "#{trace["trace_id"]} / #{trace["span_id"]}"

      is_binary(trace["trace_id"]) ->
        trace["trace_id"]

      true ->
        nil
    end
  end

  def sdk_summary(event) do
    sdk = event.details["sdk"] || %{}

    %{
      "name" => sdk["name"],
      "version" => sdk["version"],
      "packages" => package_summary(sdk["packages"]),
      "integrations" => integration_summary(sdk["integrations"])
    }
    |> Enum.reject(fn {_key, value} -> blank_detail?(value) end)
    |> Map.new()
  end

  def visible_contexts(contexts) when is_map(contexts) do
    contexts
    |> Map.take(~w(app runtime os device culture cloud_resource trace))
    |> Enum.reject(fn {_name, values} -> blank_detail?(values) end)
    |> Enum.map(fn {name, values} -> {name, values |> flatten_context() |> sorted_take(8)} end)
    |> Enum.reject(fn {_name, values} -> values == [] end)
    |> Enum.sort_by(fn {name, _values} -> context_order(name) end)
  end

  def visible_contexts(_contexts), do: []

  def format_context_detail(key, value) when is_integer(value) do
    if memory_key?(key) and value >= 0 do
      format_bytes(value)
    else
      format_detail(value)
    end
  end

  def format_context_detail(_key, value), do: format_detail(value)

  def format_detail(value) when is_binary(value), do: value
  def format_detail(value) when is_integer(value), do: Integer.to_string(value)
  def format_detail(value) when is_float(value), do: Float.to_string(value)
  def format_detail(value) when is_boolean(value), do: to_string(value)

  def format_detail(value) when is_list(value),
    do: value |> Enum.map(&format_detail/1) |> Enum.join(", ")

  def format_detail(value), do: inspect(value)

  def frame_location(frame) do
    filename = frame["filename"] || frame["abs_path"] || "unknown"
    line = frame["lineno"] || "?"
    column = frame["colno"]

    if column do
      "#{filename}:#{line}:#{column}"
    else
      "#{filename}:#{line}"
    end
  end

  def frame_source_lines(frame) do
    pre_context = list_value(frame["pre_context"])
    context_line = frame["context_line"]
    post_context = list_value(frame["post_context"])

    case {pre_context, context_line, post_context} do
      {[], nil, []} ->
        []

      _ ->
        current_line_number = integer_value(frame["lineno"])
        first_line_number = first_source_line_number(current_line_number, length(pre_context))

        pre_context
        |> Enum.concat(List.wrap(context_line))
        |> Enum.concat(post_context)
        |> Enum.with_index()
        |> Enum.map(fn {source, index} ->
          source_line_number = source_line_number(first_line_number, index)

          %{
            id: index + 1,
            number: source_line_number || "",
            source: source,
            current?: current_line_number != nil and source_line_number == current_line_number
          }
        end)
    end
  end

  def frame_var_pairs(%{"vars" => vars}) when is_map(vars) do
    sorted_take(vars, 16)
  end

  def frame_var_pairs(_frame), do: []

  def frame_language(frame) do
    frame
    |> frame_filename()
    |> Path.extname()
    |> String.downcase()
    |> case do
      ".py" -> "python"
      ".pyw" -> "python"
      ".js" -> "javascript"
      ".mjs" -> "javascript"
      ".cjs" -> "javascript"
      ".jsx" -> "jsx"
      ".ts" -> "typescript"
      ".mts" -> "typescript"
      ".cts" -> "typescript"
      ".tsx" -> "tsx"
      ".rb" -> "ruby"
      ".php" -> "php"
      ".java" -> "java"
      ".kt" -> "kotlin"
      ".kts" -> "kotlin"
      ".cs" -> "csharp"
      ".go" -> "go"
      ".rs" -> "rust"
      ".swift" -> "swift"
      ".m" -> "objectivec"
      ".mm" -> "objectivec"
      ".dart" -> "dart"
      ".c" -> "c"
      ".h" -> "c"
      ".cc" -> "cpp"
      ".cpp" -> "cpp"
      ".cxx" -> "cpp"
      ".hpp" -> "cpp"
      ".hh" -> "cpp"
      ".hxx" -> "cpp"
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".json" -> "json"
      _ -> nil
    end
  end

  def dom_id_part(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "value"
      value -> value
    end
  end

  def raw_event_json(value), do: Jason.encode!(value, pretty: true)

  def format_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

  defp package_summary(packages) when is_list(packages) do
    packages
    |> Enum.take(3)
    |> Enum.map(fn
      %{"name" => name, "version" => version} -> "#{name}@#{version}"
      value -> format_detail(value)
    end)
    |> Enum.join(", ")
  end

  defp package_summary(_packages), do: nil

  defp integration_summary(integrations) when is_list(integrations) do
    count = length(integrations)

    integrations
    |> Enum.take(8)
    |> Enum.join(", ")
    |> then(fn summary ->
      if count > 8, do: "#{summary}, +#{count - 8} more", else: summary
    end)
  end

  defp integration_summary(_integrations), do: nil

  defp flatten_context(values) when is_map(values) do
    values
    |> Enum.reject(fn {_key, value} -> blank_detail?(value) end)
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
  end

  defp flatten_context(_values), do: []

  defp sorted_take(values, count) when is_map(values) do
    values
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> sorted_take(count)
  end

  defp sorted_take(values, count) when is_list(values) do
    values
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.take(count)
  end

  defp sorted_take(_values, _count), do: []

  defp memory_key?(key) do
    key
    |> to_string()
    |> String.downcase()
    |> String.contains?("memory")
  end

  defp format_bytes(bytes) when bytes >= 1024 * 1024 * 1024 do
    bytes
    |> Kernel./(1024 * 1024 * 1024)
    |> format_unit("GB")
  end

  defp format_bytes(bytes) when bytes >= 1024 * 1024 do
    bytes
    |> Kernel./(1024 * 1024)
    |> format_unit("MB")
  end

  defp format_bytes(bytes) when bytes >= 1024 do
    bytes
    |> Kernel./(1024)
    |> format_unit("KB")
  end

  defp format_bytes(bytes), do: "#{bytes} B"

  defp format_unit(value, unit) do
    formatted =
      if value == trunc(value) do
        Integer.to_string(trunc(value))
      else
        :erlang.float_to_binary(value, decimals: 1)
      end

    "#{formatted} #{unit}"
  end

  defp context_order("app"), do: 1
  defp context_order("runtime"), do: 2
  defp context_order("os"), do: 3
  defp context_order("device"), do: 4
  defp context_order("culture"), do: 5
  defp context_order("trace"), do: 6
  defp context_order(_name), do: 99

  defp blank_detail?(nil), do: true
  defp blank_detail?(""), do: true
  defp blank_detail?(value) when is_map(value), do: map_size(value) == 0
  defp blank_detail?(value) when is_list(value), do: value == []
  defp blank_detail?(_value), do: false

  defp frame_filename(frame), do: frame["filename"] || frame["abs_path"] || ""

  defp first_source_line_number(nil, _pre_context_count), do: nil

  defp first_source_line_number(line_number, pre_context_count),
    do: line_number - pre_context_count

  defp source_line_number(nil, _index), do: nil
  defp source_line_number(first_line_number, index), do: first_line_number + index

  defp list_value(value) when is_list(value) do
    Enum.filter(value, &is_binary/1)
  end

  defp list_value(_value), do: []

  defp integer_value(value) when is_integer(value), do: value
  defp integer_value(_value), do: nil
end
