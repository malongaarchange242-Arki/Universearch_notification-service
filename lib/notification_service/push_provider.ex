defmodule NotificationService.PushProvider do
  @callback deliver(
              struct(),
              struct(),
              map()
            ) :: {:ok, map()} | {:error, term()}

  def deliver(device_token, notification, payload) do
    provider().deliver(device_token, notification, payload)
  end

  defp provider do
    Application.get_env(
      :notification_service,
      :push_provider,
      NotificationService.Push.Providers.FCMV1
    )
  end
end
