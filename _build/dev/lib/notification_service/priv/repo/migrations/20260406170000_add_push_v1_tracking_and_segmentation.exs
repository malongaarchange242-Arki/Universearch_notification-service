defmodule NotificationService.Repo.Migrations.AddPushV1TrackingAndSegmentation do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :title, :string
      add :priority, :string, default: "high", null: false
      add :deep_link, :string
      add :collapse_key, :string
      add :silent, :boolean, default: false, null: false
      add :campaign_type, :string, default: "transactional", null: false
      add :sponsor_id, :string
    end

    alter table(:device_tokens) do
      add :provider, :string, default: "fcm", null: false
      add :user_type, :string
      add :interests, {:array, :string}, default: [], null: false
      add :locale, :string
      add :device_id, :string
      add :last_seen_at, :utc_datetime_usec
      add :disabled_at, :utc_datetime_usec
      add :failure_count, :integer, default: 0, null: false
      add :last_error, :text
      add :metadata, :map, default: %{}, null: false
    end

    create index(:device_tokens, [:user_id, :disabled_at])
    create index(:device_tokens, [:user_type])
    create index(:device_tokens, [:platform])

    create table(:notification_events) do
      add :notification_id, references(:notifications, on_delete: :delete_all), null: false
      add :device_token_id, references(:device_tokens, on_delete: :nilify_all)
      add :user_id, :string, null: false
      add :event_type, :string, null: false
      add :channel, :string, null: false, default: "push"
      add :provider, :string, null: false, default: "fcm_v1"
      add :status, :string, null: false, default: "success"
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
      add :created_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
    end

    create index(:notification_events, [:notification_id])
    create index(:notification_events, [:notification_id, :event_type])
    create index(:notification_events, [:user_id, :event_type])
    create index(:notification_events, [:device_token_id])
  end
end
