defmodule FaultlineWeb.TimeComponents do
  @moduledoc false

  use FaultlineWeb, :html

  attr :id, :string, required: true
  attr :datetime, :any, required: true
  attr :class, :string, default: nil
  attr :format, :string, default: "minute"

  def local_time(assigns) do
    assigns =
      assigns
      |> assign(:iso_datetime, iso_datetime(assigns.datetime))
      |> assign(:fallback, fallback_time(assigns.datetime))

    ~H"""
    <time
      id={@id}
      datetime={@iso_datetime}
      phx-hook="LocalTime"
      data-local-time-format={@format}
      class={@class}
    >
      {@fallback}
    </time>
    """
  end

  defp iso_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso_datetime(value), do: to_string(value)

  defp fallback_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  defp fallback_time(value), do: to_string(value)
end
