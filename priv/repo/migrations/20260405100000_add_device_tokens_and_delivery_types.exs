defmodule NotificationService.Repo.Migrations.AddDeviceTokensAndDeliveryTypes do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :delivery_types, {:array, :string}, default: ["in_app", "push"], null: false
    end

    create table(:device_tokens) do
      add :user_id, :string, null: false
      add :token, :text, null: false
      add :platform, :string, null: false
      add :created_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end

    create index(:device_tokens, [:user_id])
    create unique_index(:device_tokens, [:token])
  end
end
