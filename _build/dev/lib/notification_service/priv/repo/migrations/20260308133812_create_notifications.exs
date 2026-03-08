defmodule NotificationService.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, :integer
      add :type, :string
      add :message, :string
      add :read, :boolean, default: false

      timestamps()
    end

    # Performance indexes for unread count queries
    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read])
  end
end

# Authentification obligatoire
def connect(%{"token" => token}, socket, _connect_info) do
  case verify_user(token) do
    {:ok, user_id} -> {:ok, assign(socket, :user_id, user_id)}
    :error -> :error
  end
end

# Vérification d'autorisation
def join("notifications:" <> requested_user_id, _params, socket) do
  if socket.assigns.user_id == requested_user_id do
    {:ok, socket}
  else
    {:error, %{reason: "unauthorized"}}
  end
end

# Création notification
increment_unread_count(user_id)  # INSERT ... ON CONFLICT

# Lecture compteur
unread_count(user_id)  # SELECT unread_count (0.2ms)

config :notification_service, NotificationServiceWeb.Endpoint,
  pubsub_server: NotificationService.PubSub
