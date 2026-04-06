defmodule NotificationService.Services.NotificationEventService do
  import Ecto.Query

  alias NotificationService.Models.DeviceToken
  alias NotificationService.Models.Notification
  alias NotificationService.Models.NotificationEvent
  alias NotificationService.Repo

  @client_event_types ["delivered", "opened", "clicked"]

  def record_event(attrs) when is_map(attrs) do
    %NotificationEvent{}
    |> NotificationEvent.changeset(attrs)
    |> Repo.insert()
  end

  def record_delivery_state(notification, device_token, event_type, metadata \\ %{})
      when is_map(notification) and is_map(device_token) and
             event_type in ["queued", "sent", "failed", "token_invalid"] do
    record_event(%{
      notification_id: Map.get(notification, :id),
      device_token_id: Map.get(device_token, :id),
      user_id: Map.get(notification, :user_id),
      event_type: event_type,
      channel: "push",
      provider: "fcm_v1",
      status: event_status(event_type, metadata),
      metadata: metadata
    })
  end

  def track_client_event(notification_id, user_id, event_type, metadata \\ %{}, token \\ nil)

  def track_client_event(notification_id, user_id, event_type, metadata, token)
      when event_type in @client_event_types do
    with %Notification{} = notification <- Repo.get(Notification, notification_id),
         true <- notification.user_id == user_id do
      device_token_id =
        case token do
          value when is_binary(value) and value != "" ->
            find_device_token_id(user_id, value)

          _ ->
            nil
        end

      record_event(%{
        notification_id: notification.id,
        device_token_id: device_token_id,
        user_id: user_id,
        event_type: event_type,
        channel: "push",
        provider: "fcm_v1",
        status: "success",
        metadata: metadata
      })
    else
      nil -> {:error, :not_found}
      false -> {:error, :forbidden}
    end
  end

  def track_client_event(_notification_id, _user_id, _event_type, _metadata, _token) do
    {:error, :invalid_event_type}
  end

  def analytics(notification_id) do
    counts =
      from(e in NotificationEvent,
        where: e.notification_id == ^notification_id,
        group_by: e.event_type,
        select: {e.event_type, count(e.id)}
      )
      |> Repo.all()
      |> Map.new()

    queued = Map.get(counts, "queued", 0)
    sent = Map.get(counts, "sent", 0)
    delivered = Map.get(counts, "delivered", 0)
    opened = Map.get(counts, "opened", 0)
    clicked = Map.get(counts, "clicked", 0)
    failed = Map.get(counts, "failed", 0) + Map.get(counts, "token_invalid", 0)

    denominator = max(sent, queued)

    %{
      queued: queued,
      sent: sent,
      delivered: delivered,
      opened: opened,
      clicked: clicked,
      failed: failed,
      delivery_rate: ratio(delivered, denominator),
      open_rate: ratio(opened, max(delivered, sent)),
      ctr: ratio(clicked, max(delivered, sent))
    }
  end

  defp event_status("queued", _metadata), do: "queued"
  defp event_status("failed", metadata),
    do:
      if(Map.get(metadata, "retryable") == true or Map.get(metadata, :retryable) == true,
        do: "retryable",
        else: "failed"
      )
  defp event_status("token_invalid", _metadata), do: "cancelled"
  defp event_status(_event_type, _metadata), do: "success"

  defp find_device_token_id(user_id, token) do
    from(dt in DeviceToken,
      where: dt.user_id == ^user_id and dt.token == ^token
    )
    |> Repo.one()
    |> case do
      nil -> nil
      device_token -> device_token.id
    end
  end

  defp ratio(_value, 0), do: 0.0
  defp ratio(value, denominator), do: Float.round(value / denominator, 4)
end
