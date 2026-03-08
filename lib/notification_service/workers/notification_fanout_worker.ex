defmodule NotificationService.Workers.NotificationFanoutWorker do
  use Oban.Worker, queue: :fanout

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"notification_id" => notification_id}}) do
    # Get the notification
    case NotificationService.Repo.get(NotificationService.Models.Notification, notification_id) do
      nil ->
        {:error, "Notification not found"}

      notification ->
        # Broadcast to the specific user via Phoenix PubSub
        NotificationServiceWeb.Endpoint.broadcast(
          "notifications:#{notification.user_id}",
          "new_notification",
          %{
            notification: notification,
            unread_count: NotificationService.Services.NotificationService.unread_count(notification.user_id)
          }
        )

        # Here you could also:
        # - Send push notifications
        # - Send emails
        # - Update user stats table
        # - Trigger other background jobs

        :ok
    end
  end
end