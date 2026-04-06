defmodule NotificationService.Workers.NotificationWorker do
  use Oban.Worker,
    queue: :push_delivery,
    max_attempts: 3,
    unique: [period: 60, fields: [:worker, :args]]

  alias NotificationService.Models.Notification
  alias NotificationService.PushProvider
  alias NotificationService.Repo
  alias NotificationService.Services.DeviceTokenService
  alias NotificationService.Services.NotificationEventService

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"notification_id" => notification_id, "device_token_id" => device_token_id},
        attempt: attempt
      }) do
    with %Notification{} = notification <- Repo.get(Notification, notification_id),
         device_token when not is_nil(device_token) <- DeviceTokenService.get_active_token(device_token_id) do
      Logger.metadata(
        notification_id: notification_id,
        device_token_id: device_token_id,
        user_id: notification.user_id
      )

      payload = NotificationService.Services.NotificationService.push_payload(notification)

      case PushProvider.deliver(device_token, notification, payload) do
        {:ok, response} ->
          DeviceTokenService.mark_success(device_token)

          NotificationEventService.record_delivery_state(
            notification,
            device_token,
            "sent",
            %{
              "attempt" => attempt,
              "provider_response" => response
            }
          )

          :ok

        {:error, {:invalid_token, reason, details}} ->
          DeviceTokenService.disable_token(device_token, reason)

          NotificationEventService.record_delivery_state(
            notification,
            device_token,
            "token_invalid",
            %{
              "attempt" => attempt,
              "reason" => reason,
              "details" => details
            }
          )

          {:cancel, "invalid_token"}

        {:error, {:retryable, reason, details}} ->
          NotificationEventService.record_delivery_state(
            notification,
            device_token,
            "failed",
            %{
              "attempt" => attempt,
              "reason" => reason,
              "details" => details,
              "retryable" => true
            }
          )

          {:error, inspect(reason)}

        {:error, {:fatal, reason, details}} ->
          NotificationEventService.record_delivery_state(
            notification,
            device_token,
            "failed",
            %{
              "attempt" => attempt,
              "reason" => reason,
              "details" => details,
              "retryable" => false
            }
          )

          {:cancel, inspect(reason)}

        {:error, reason} ->
          NotificationEventService.record_delivery_state(
            notification,
            device_token,
            "failed",
            %{
              "attempt" => attempt,
              "reason" => inspect(reason),
              "retryable" => true
            }
          )

          {:error, inspect(reason)}
      end
    else
      nil ->
        {:cancel, "missing_notification_or_device_token"}
    end
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    trunc(:math.pow(attempt, 4) + 15)
  end
end
