defmodule FaultlineWeb.IssueLive.EventDetailTest do
  use ExUnit.Case, async: true

  alias FaultlineWeb.IssueLive.EventDetail

  test "builds compact event titles" do
    assert EventDetail.compact_exception(%{
             exception_type: "TypeError",
             exception_value: "Cannot read properties of undefined"
           }) == "TypeError: Cannot read properties of undefined"

    assert EventDetail.occurrence_title(%{
             exception_type: nil,
             exception_value: nil,
             message: "Checkout failed"
           }) == "Checkout failed"
  end

  test "formats context memory values without changing ordinary integers" do
    assert EventDetail.format_context_detail("app_memory", 105_168_896) == "100.3 MB"
    assert EventDetail.format_context_detail("memory_size", 19_327_352_832) == "18 GB"
    assert EventDetail.format_context_detail("processor_count", 11) == "11"
  end

  test "summarizes sdk detail for display" do
    event = %{
      details: %{
        "sdk" => %{
          "name" => "sentry.javascript.node",
          "version" => "10.57.0",
          "packages" => [%{"name" => "npm:@sentry/node", "version" => "10.57.0"}],
          "integrations" => Enum.map(1..10, &"Integration#{&1}")
        }
      }
    }

    assert EventDetail.sdk_summary(event) == %{
             "name" => "sentry.javascript.node",
             "version" => "10.57.0",
             "packages" => "npm:@sentry/node@10.57.0",
             "integrations" =>
               "Integration1, Integration2, Integration3, Integration4, Integration5, Integration6, Integration7, Integration8, +2 more"
           }
  end

  test "prepares source frame rows" do
    frame = %{
      "filename" => "app.js",
      "lineno" => 42,
      "pre_context" => ["const amount = cart.total"],
      "context_line" => "throw new TypeError()",
      "post_context" => ["return charge"]
    }

    assert EventDetail.frame_language(frame) == "javascript"

    assert EventDetail.frame_source_lines(frame) == [
             %{id: 1, number: 41, source: "const amount = cart.total", current?: false},
             %{id: 2, number: 42, source: "throw new TypeError()", current?: true},
             %{id: 3, number: 43, source: "return charge", current?: false}
           ]
  end
end
