defmodule NotificationService.Repo.Migrations.CreateUserNotificationStats do
  use Ecto.Migration

  def change do
    create table(:user_notification_stats) do
      add :user_id, :integer, null: false
      add :unread_count, :integer, default: 0, null: false

      timestamps()
    end

    create unique_index(:user_notification_stats, [:user_id])
  end
end
