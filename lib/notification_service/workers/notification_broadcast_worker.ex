defmodule NotificationService.Workers.NotificationBroadcastWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 5

  alias NotificationService.Services.NotificationService

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, id: job_id}) when is_map(args) do
    case NotificationService.broadcast_notifications(args) do
      {:ok, %{count: count, errors: errors}} ->
        if errors != [] do
          Logger.warning(
            "Broadcast completed with partial errors",
            job_id: job_id,
            delivered_count: count,
            error_count: length(errors)
          )
        else
          Logger.info(
            "Broadcast completed",
            job_id: job_id,
            delivered_count: count
          )
        end

        :ok

      {:error, reasons} ->
        Logger.error(
          "Broadcast failed",
          job_id: job_id,
          reason: inspect(reasons)
        )

        {:error, inspect(reasons)}
    end
  end
end
