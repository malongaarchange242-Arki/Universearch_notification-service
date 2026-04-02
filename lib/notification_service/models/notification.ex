defmodule NotificationService.Models.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :user_id, :string
    field :type, :string
    field :message, :string
    field :data, :map, default: %{}
    field :read, :boolean, default: false

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :type, :message, :data, :read])
    |> validate_required([:user_id, :type, :message])
  end
end
