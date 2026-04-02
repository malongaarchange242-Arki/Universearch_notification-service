defmodule NotificationService.Repo.Migrations.AddUuidAndDataToNotifications do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      modify :user_id, :string
      add :data, :map, default: %{}, null: false
    end

    alter table(:user_notification_stats) do
      modify :user_id, :string
    end
  end
end
