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

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read])
  end
end
