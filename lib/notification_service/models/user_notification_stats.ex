defmodule NotificationService.Models.UserNotificationStats do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_notification_stats" do
    field :user_id, :integer
    field :unread_count, :integer, default: 0

    timestamps()
  end

  def changeset(stats, attrs) do
    stats
    |> cast(attrs, [:user_id, :unread_count])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end