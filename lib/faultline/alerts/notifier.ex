defmodule Faultline.Alerts.Notifier do
  @moduledoc """
  Sends alert notifications through the configured alert rule channel.
  """

  import Swoosh.Email

  alias Faultline.Alerts.AlertRule
  alias Faultline.Events.Event
  alias Faultline.Issues.Issue
  alias Faultline.Mailer
  alias Faultline.Projects.Project

  @type context :: %{
          required(:project) => Project.t(),
          required(:issue) => Issue.t(),
          optional(:event) => Event.t() | nil,
          required(:trigger) => String.t()
        }

  @spec deliver(AlertRule.t(), context()) :: :ok | {:error, term()}
  def deliver(%AlertRule{channel: "email"} = rule, context) do
    email =
      new()
      |> to(rule.target)
      |> from({"Faultline", "contact@example.com"})
      |> subject(subject(context))
      |> text_body(body(context))

    case Mailer.deliver(email) do
      {:ok, _metadata} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def deliver(%AlertRule{channel: "webhook"} = rule, context) do
    post_json(rule.target, payload(context))
  end

  def deliver(%AlertRule{channel: "slack"} = rule, context) do
    post_json(rule.target, slack_payload(context))
  end

  defp post_json(url, payload) do
    case http_client().post(url, json: payload) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp http_client do
    :faultline
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:http_client, Req)
  end

  defp subject(context) do
    "[Faultline] #{trigger_label(context.trigger)}: #{context.issue.title}"
  end

  defp body(context) do
    """
    #{trigger_label(context.trigger)} in #{context.project.name}

    #{context.issue.title}

    Status: #{context.issue.status}
    Events: #{context.issue.event_count}
    Last seen: #{format_time(context.issue.last_seen_at)}
    """
  end

  defp payload(context) do
    %{
      trigger: context.trigger,
      project: %{
        id: context.project.id,
        name: context.project.name,
        slug: context.project.slug
      },
      issue: %{
        id: context.issue.id,
        title: context.issue.title,
        status: context.issue.status,
        event_count: context.issue.event_count,
        affected_user_count: context.issue.affected_user_count,
        first_seen_at: context.issue.first_seen_at,
        last_seen_at: context.issue.last_seen_at
      },
      event: event_payload(Map.get(context, :event))
    }
  end

  defp slack_payload(context) do
    %{
      text: "#{trigger_label(context.trigger)} in #{context.project.name}: #{context.issue.title}"
    }
  end

  defp event_payload(nil), do: nil

  defp event_payload(event) do
    %{
      id: event.id,
      event_id: event.event_id,
      level: event.level,
      platform: event.platform,
      release: event.release,
      environment: event.environment,
      occurred_at: event.occurred_at
    }
  end

  defp trigger_label("new_issue"), do: "New issue"
  defp trigger_label("regression"), do: "Regression"
  defp trigger_label("frequency"), do: "Frequency alert"
  defp trigger_label(trigger), do: trigger

  defp format_time(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")

  defp format_time(_datetime), do: "unknown"
end
