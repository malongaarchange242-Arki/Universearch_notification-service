defmodule NotificationService.Controllers.NotificationController do
  use Phoenix.Controller, formats: [:json]

  alias NotificationService.Services.NotificationService

  def index(conn, %{"user_id" => user_id}) do
    current_user_id = conn.assigns[:current_user_id]

    if current_user_id != user_id do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Forbidden"})
    else
      notifications = NotificationService.get_user_notifications(user_id)
      json(conn, %{notifications: notifications})
    end
  end

  def index(conn, _params) do
    current_user_id = conn.assigns[:current_user_id]
    notifications = NotificationService.get_user_notifications(current_user_id)
    json(conn, %{notifications: notifications})
  end

  def create(conn, params) do
    notification_params =
      case params do
        %{"notification" => wrapped} when is_map(wrapped) -> wrapped
        bare when is_map(bare) -> bare
        _ -> %{}
      end

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

  def broadcast(conn, params) do
    notification_params =
      case params do
        %{"notification" => wrapped} when is_map(wrapped) -> wrapped
        bare when is_map(bare) -> bare
        _ -> %{}
      end

    case NotificationService.enqueue_broadcast_notifications(notification_params) do
      {:ok, result} ->
        conn
        |> put_status(:created)
        |> json(%{
          count: result.count,
          notification_ids: [],
          errors: result.errors,
          status: "queued",
          job_id: result.job_id
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})

      {:error, reasons} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Enum.map(List.wrap(reasons), &inspect/1)})
    end
  end

  def unread_count(conn, %{"user_id" => user_id}) do
    current_user_id = conn.assigns[:current_user_id]

    if current_user_id != user_id do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Forbidden"})
    else
      count = NotificationService.unread_count(user_id)
      json(conn, %{unread_count: count})
    end
  end

  def mark_as_read(conn, %{"id" => notification_id}) do
    user_id = conn.assigns[:current_user_id]

    case NotificationService.mark_as_read(notification_id, user_id) do
      {:ok, notification} ->
        json(conn, %{notification: notification})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def delete(conn, %{"id" => notification_id}) do
    user_id = conn.assigns[:current_user_id]

    case NotificationService.delete_notification(notification_id, user_id) do
      {:ok, notification} ->
        json(conn, %{notification: notification})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Notification not found"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Unauthorized"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def delete_all(conn, _params) do
    user_id = conn.assigns[:current_user_id]

    {:ok, count} = NotificationService.delete_all_notifications(user_id)
    json(conn, %{deleted_count: count})
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
