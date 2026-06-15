defmodule Faultline.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        FaultlineWeb.Telemetry,
        Faultline.Repo,
        {DNSCluster, query: Application.get_env(:faultline, :dns_cluster_query) || :ignore},
        retention_cleanup_worker(),
        {Phoenix.PubSub, name: Faultline.PubSub},
        # Start a worker by calling: Faultline.Worker.start_link(arg)
        # {Faultline.Worker, arg},
        # Start to serve requests, typically the last entry
        FaultlineWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Faultline.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FaultlineWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp retention_cleanup_worker do
    config = Application.get_env(:faultline, Faultline.Retention.CleanupWorker, [])

    if Keyword.get(config, :enabled, true) do
      {Faultline.Retention.CleanupWorker, interval_ms: Keyword.fetch!(config, :interval_ms)}
    end
  end
end
