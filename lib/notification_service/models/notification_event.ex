defmodule NotificationService.Models.NotificationEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :notification_id,
             :device_token_id,
             :user_id,
             :event_type,
             :channel,
             :provider,
             :status,
             :metadata,
             :occurred_at,
             :created_at
           ]}

  @event_types ["queued", "sent", "delivered", "opened", "clicked", "failed", "token_invalid"]
  @channels ["push", "in_app"]
  @statuses ["queued", "success", "failed", "retryable", "cancelled"]

  schema "notification_events" do
    field :user_id, :string
    field :event_type, :string
    field :channel, :string, default: "push"
    field :provider, :string, default: "fcm_v1"
    field :status, :string, default: "success"
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime_usec

    belongs_to :notification, NotificationService.Models.Notification
    belongs_to :device_token, NotificationService.Models.DeviceToken

    timestamps(inserted_at: :created_at, updated_at: false)
  end

  def changeset(event, attrs) do
    changeset =
      event
    |> cast(attrs, [
      :notification_id,
      :device_token_id,
      :user_id,
      :event_type,
      :channel,
      :provider,
      :status,
      :metadata,
      :occurred_at
    ])
    |> validate_required([:notification_id, :user_id, :event_type, :channel, :status])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_inclusion(:channel, @channels)
    |> validate_inclusion(:status, @statuses)

    case get_field(changeset, :occurred_at) do
      nil -> put_change(changeset, :occurred_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
