defmodule NotificationService.Models.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :user_id, :integer
    field :type, :string
    field :message, :string
    field :read, :boolean, default: false

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :type, :message, :read])
    |> validate_required([:user_id, :type, :message])
  end
end