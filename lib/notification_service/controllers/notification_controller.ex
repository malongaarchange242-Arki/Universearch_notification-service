defmodule NotificationService.Controllers.NotificationController do
  use Phoenix.Controller, formats: [:json]

  alias NotificationService.Services.NotificationService

  def index(conn, %{"user_id" => user_id}) do
    notifications = NotificationService.get_user_notifications(String.to_integer(user_id))
    json(conn, %{notifications: notifications})
  end

  def index(conn, _params) do
    notifications = NotificationService.list_notifications()
    json(conn, %{notifications: notifications})
  end

  def create(conn, %{"notification" => notification_params}) do
    case NotificationService.create_notification(notification_params) do
      {:ok, notification} ->
        conn
        |> put_status(:created)
        |> json(%{notification: notification})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def unread_count(conn, %{"user_id" => user_id}) do
    count = NotificationService.unread_count(String.to_integer(user_id))
    json(conn, %{unread_count: count})
  end

  def mark_as_read(conn, %{"id" => notification_id}) do
    # In a real app, you'd get user_id from authentication
    # For now, we'll assume it's passed or extracted from conn
    user_id = get_user_id_from_conn(conn) # You'll need to implement this

    case NotificationService.mark_as_read(String.to_integer(notification_id), user_id) do
      {:ok, notification} ->
        json(conn, %{notification: notification})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  defp get_user_id_from_conn(_conn) do
    # Extract user_id from authentication token/session
    # This is a placeholder - implement based on your auth system
    1 # Default for testing
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end