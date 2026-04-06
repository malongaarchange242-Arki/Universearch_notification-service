defmodule NotificationService.Services.FcmService do
  @moduledoc false

  @deprecated "Use NotificationService.PushProvider / NotificationService.Push.Providers.FCMV1 instead."
  def deliver(_token, _payload) do
    {:error, :legacy_fcm_removed}
  end
end
