defmodule NotificationService.Services.NotificationService do
  alias NotificationService.Models.Notification
  alias NotificationService.Models.UserNotificationStats
  alias NotificationService.Repo
  import Ecto.Query

  def list_notifications do
    Repo.all(Notification)
  end

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        # Increment unread count in stats table (ultra-fast)
        increment_unread_count(notification.user_id)

        # Schedule fanout job for real-time delivery (production architecture)
        %{notification_id: notification.id}
        |> NotificationService.Workers.NotificationFanoutWorker.new()
        |> Oban.insert()

        # Also schedule external notification delivery
        %{notification_id: notification.id}
        |> NotificationService.Workers.NotificationWorker.new()
        |> Oban.insert()

        {:ok, notification}

      error ->
        error
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

          notification
          |> Notification.changeset(%{read: true})
          |> Repo.update()
        end
    end
  end

  def get_user_notifications(user_id) do
    Repo.all(from n in Notification, where: n.user_id == ^user_id, order_by: [desc: n.inserted_at])
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
end
