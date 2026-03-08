defmodule NotificationService.Workers.NotificationWorker do
  use Oban.Worker, queue: :notifications

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"notification_id" => notification_id}}) do
    # Logic to send notification via external services
    # For example, send email or push notification
    IO.puts("Sending notification #{notification_id} via external service")
    :ok
  end
end