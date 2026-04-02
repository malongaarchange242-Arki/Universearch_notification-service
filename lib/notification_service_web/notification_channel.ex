defmodule NotificationServiceWeb.NotificationChannel do
  use Phoenix.Channel

  @impl true
  def join("notifications:" <> requested_user_id, _params, socket) do
    authenticated_user_id = socket.assigns.user_id

    if to_string(authenticated_user_id) == requested_user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Handle incoming messages from client (optional)
  @impl true
  def handle_in("mark_as_read", %{"notification_id" => notification_id}, socket) do
    user_id = socket.assigns.user_id

    case NotificationService.Services.NotificationService.mark_as_read(notification_id, user_id) do
      {:ok, notification} ->
        # Broadcast to all clients of this user that notification was read
        broadcast(socket, "notification_read", %{notification: notification})
        {:reply, {:ok, notification}, socket}

      {:error, reason} ->
        {:reply, {:error, reason}, socket}
    end
  end

  # Handle ping from client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
