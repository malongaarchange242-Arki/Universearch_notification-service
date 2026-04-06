defmodule NotificationService.Controllers.NotificationEventController do
  use Phoenix.Controller, formats: [:json]

  alias NotificationService.Services.NotificationEventService

  def create(conn, %{"id" => notification_id} = params) do
    user_id = conn.assigns[:current_user_id]
    event_type = params["event_type"] || params["type"]
    metadata = Map.get(params, "metadata", %{})
    token = params["token"]

    case NotificationEventService.track_client_event(notification_id, user_id, event_type, metadata, token) do
      {:ok, event} ->
        conn
        |> put_status(:created)
        |> json(%{event: event})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Notification not found"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Forbidden"})

      {:error, :invalid_event_type} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Unsupported event type"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def analytics(conn, %{"id" => notification_id}) do
    user_id = conn.assigns[:current_user_id]

    case NotificationService.Repo.get(NotificationService.Models.Notification, notification_id) do
      %NotificationService.Models.Notification{user_id: ^user_id} ->
        json(conn, %{analytics: NotificationEventService.analytics(notification_id)})

      %NotificationService.Models.Notification{} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Forbidden"})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Notification not found"})
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
