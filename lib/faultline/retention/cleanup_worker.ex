defmodule Faultline.Retention.CleanupWorker do
  @moduledoc """
  Runs periodic retention cleanup on the local node.

  This intentionally stays as a small GenServer so single-node deployments do not
  need a separate queue or scheduler service.
  """

  use GenServer

  alias Faultline.Retention

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval_ms = Keyword.fetch!(opts, :interval_ms)

    if interval_ms > 0 do
      schedule_cleanup(interval_ms)
    end

    {:ok, %{interval_ms: interval_ms}}
  end

  @impl true
  def handle_info(:cleanup, %{interval_ms: interval_ms} = state) do
    _result = Retention.cleanup_all_projects()
    schedule_cleanup(interval_ms)
    {:noreply, state}
  end

  defp schedule_cleanup(interval_ms) do
    Process.send_after(self(), :cleanup, interval_ms)
  end
end
