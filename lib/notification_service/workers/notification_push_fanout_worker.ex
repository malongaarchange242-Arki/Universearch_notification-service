defmodule NotificationService.Workers.NotificationPushFanoutWorker do
  use Oban.Worker, queue: :push_fanout, max_attempts: 5

  alias NotificationService.Models.Notification
  alias NotificationService.Repo
  alias NotificationService.Services.DeviceTokenService
  alias NotificationService.Services.NotificationEventService

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"notification_id" => notification_id}}) do
    case Repo.get(Notification, notification_id) do
      nil ->
        {:cancel, "notification_not_found"}

      notification ->
        notification.user_id
        |> DeviceTokenService.get_active_user_tokens()
        |> enqueue_push_jobs(notification)
    end
  end

  defp enqueue_push_jobs([], _notification) do
    :ok
  end

  defp enqueue_push_jobs(device_tokens, notification) do
    Enum.each(device_tokens, fn device_token ->
      NotificationEventService.record_delivery_state(
        notification,
        device_token,
        "queued",
        %{
          "priority" => notification.priority,
          "campaign_type" => notification.campaign_type
        }
      )

      %{
        notification_id: notification.id,
        device_token_id: device_token.id
      }
      |> NotificationService.Workers.NotificationWorker.new(
        priority: if(notification.priority == "normal", do: 5, else: 1)
      )
      |> Oban.insert()
    end)

    :ok
  end
end
