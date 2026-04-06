defmodule NotificationService.Services.NotificationService do
  alias NotificationService.Models.Notification
  alias NotificationService.Models.UserNotificationStats
  alias NotificationService.Repo
  alias NotificationService.Services.DeviceTokenService
  alias NotificationService.Services.NotificationEventService

  import Ecto.Query

  def list_notifications do
    Repo.all(Notification)
  end

  def create_notification(attrs) do
    attrs = prepare_notification_attrs(attrs)

    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        # Increment unread count in stats table (ultra-fast)
        increment_unread_count(notification.user_id)

        maybe_schedule_fanout(notification)

        maybe_schedule_push(notification)

        {:ok, notification}

      error ->
        error
    end
  end

  def broadcast_notifications(attrs) do
    attrs = prepare_notification_attrs(attrs)

    recipients =
      attrs
      |> resolve_recipients()
      |> Enum.uniq()

    {successes, errors} =
      Enum.reduce(recipients, {[], []}, fn user_id, {ok_acc, error_acc} ->
        payload =
          attrs
          |> Map.drop(["user_ids", "targeting"])
          |> Map.put("user_id", user_id)

        case create_notification(payload) do
          {:ok, notification} -> {[notification | ok_acc], error_acc}
          {:error, reason} -> {ok_acc, [reason | error_acc]}
        end
      end)

    case {Enum.reverse(successes), Enum.reverse(errors)} do
      {[], reasons} -> {:error, reasons}
      {notifications, reasons} -> {:ok, %{notifications: notifications, errors: reasons, count: length(notifications)}}
    end
  end

  def unread_count(user_id) do
    # Ultra-fast: read from stats table instead of counting notifications
    case Repo.get_by(UserNotificationStats, user_id: user_id) do
      nil -> 0
      stats -> stats.unread_count
    end
  end

  def mark_as_read(notification_id, user_id) do
    case Repo.get(Notification, notification_id) do
      nil ->
        {:error, "Notification not found"}

      notification ->
        if notification.user_id != user_id do
          {:error, "Unauthorized"}
        else
          if !notification.read do
            # Decrement unread count
            decrement_unread_count(user_id)
          end

          result =
            notification
            |> Notification.changeset(%{read: true})
            |> Repo.update()

          if !notification.read and match?({:ok, _}, result) do
            NotificationEventService.record_event(%{
              notification_id: notification.id,
              user_id: user_id,
              event_type: "opened",
              channel: "in_app",
              provider: "internal",
              status: "success",
              metadata: %{"source" => "mark_as_read"}
            })
          end

          result
        end
    end
  end

  def get_user_notifications(user_id) do
    Repo.all(from n in Notification, where: n.user_id == ^user_id, order_by: [desc: n.inserted_at])
  end

  def get_device_tokens(user_id) do
    DeviceTokenService.get_active_user_tokens(user_id)
  end

  def push_payload(%Notification{} = notification) do
    normalized_data = normalize_map_keys(notification.data)
    deep_link = Map.get(notification, :deep_link)
    campaign_type = Map.get(notification, :campaign_type, "transactional")
    sponsor_id = Map.get(notification, :sponsor_id)

    payload_data =
      normalized_data
      |> Map.take([
        "type",
        "entity_id",
        "post_id",
        "author_id",
        "actor_id",
        "deep_link",
        "campaign_type",
        "sponsor_id"
      ])
      |> Map.put_new("notification_id", to_string(notification.id))
      |> Map.put_new("type", notification.type)
      |> Map.put_new("entity_id", infer_entity_id(notification))
      |> Map.put_new("deep_link", deep_link || "")
      |> Map.put_new("campaign_type", campaign_type)
      |> maybe_put("sponsor_id", sponsor_id)
      |> Enum.into(%{}, fn {key, value} -> {key, stringify(value)} end)

    %{
      title: notification.title || Map.get(normalized_data, "title", push_title(notification)),
      body: Map.get(normalized_data, "body", notification.message),
      data: payload_data,
      priority: Map.get(notification, :priority, "high"),
      deep_link: deep_link,
      collapse_key: Map.get(notification, :collapse_key),
      silent: Map.get(notification, :silent, false)
    }
  end

  # Ultra-fast counter operations
  defp increment_unread_count(user_id) do
    Repo.insert(
      %UserNotificationStats{user_id: user_id, unread_count: 1},
      on_conflict: [inc: [unread_count: 1]],
      conflict_target: :user_id
    )
  end

  defp decrement_unread_count(user_id) do
    from(s in UserNotificationStats, where: s.user_id == ^user_id)
    |> Repo.update_all(inc: [unread_count: -1])
  end

  # Fallback method to sync stats table (run periodically)
  def sync_unread_counts do
    # This would be run as a background job to keep stats in sync
    # In case of any discrepancies
    Repo.query("""
      INSERT INTO user_notification_stats (user_id, unread_count, inserted_at, updated_at)
      SELECT
        n.user_id,
        COUNT(*) as unread_count,
        NOW(),
        NOW()
      FROM notifications n
      WHERE n.read = false
      GROUP BY n.user_id
      ON CONFLICT (user_id)
      DO UPDATE SET
        unread_count = EXCLUDED.unread_count,
        updated_at = NOW()
    """)
  end

  defp maybe_schedule_fanout(notification) do
    if "in_app" in List.wrap(notification.delivery_types) do
      %{notification_id: notification.id}
      |> NotificationService.Workers.NotificationFanoutWorker.new()
      |> Oban.insert()
    end
  end

  defp maybe_schedule_push(notification) do
    if "push" in List.wrap(notification.delivery_types) do
      %{notification_id: notification.id}
      |> NotificationService.Workers.NotificationPushFanoutWorker.new(
        priority: oban_priority(notification.priority)
      )
      |> Oban.insert()
    end
  end

  defp prepare_notification_attrs(attrs) when is_map(attrs) do
    attrs
    |> normalize_map_keys()
    |> Map.put_new("title", push_title(%Notification{type: attrs["type"] || attrs[:type]}))
    |> Map.put_new("priority", "high")
    |> Map.put_new("campaign_type", "transactional")
    |> Map.put_new("silent", false)
    |> Map.update("delivery_types", ["in_app", "push"], &normalize_delivery_types/1)
    |> Map.update("data", %{}, &normalize_map_keys/1)
  end

  defp prepare_notification_attrs(attrs), do: attrs

  defp resolve_recipients(attrs) do
    direct_user_ids =
      attrs
      |> Map.get("user_ids", [])
      |> List.wrap()
      |> Enum.map(&to_string/1)

    case direct_user_ids do
      [] ->
        case Map.get(attrs, "targeting") do
          targeting when is_map(targeting) ->
            DeviceTokenService.list_recipient_user_ids(targeting)

          _ ->
            case Map.get(attrs, "user_id") do
              nil -> []
              user_id -> [to_string(user_id)]
            end
        end

      values ->
        values
    end
  end

  defp normalize_delivery_types(values) do
    values
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
  end

  defp oban_priority("normal"), do: 5
  defp oban_priority(_priority), do: 1

  defp normalize_map_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp normalize_map_keys(_), do: %{}

  defp infer_entity_id(notification) do
    normalized_data = normalize_map_keys(notification.data)
    normalized_data["entity_id"] || normalized_data["post_id"] || notification.id
  end

  defp push_title(notification) do
    case notification.type do
      "like" -> "Nouveau like"
      "comment" -> "Nouveau commentaire"
      "orientation" -> "Nouvelle orientation"
      "inbox" -> "Nouveau message"
      "post" -> "Nouveau post"
      _ -> "Nouvelle notification"
    end
  end

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp stringify(value) when is_boolean(value), do: to_string(value)
  defp stringify(nil), do: ""
  defp stringify(value), do: Jason.encode!(value)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
