defmodule NotificationService.Models.DeviceToken do
  use Ecto.Schema
  import Ecto.Changeset

  @platforms ["web", "android", "ios"]
  @providers ["fcm"]

  schema "device_tokens" do
    field :user_id, :string
    field :token, :string
    field :platform, :string
    field :provider, :string, default: "fcm"
    field :user_type, :string
    field :interests, {:array, :string}, default: []
    field :locale, :string
    field :device_id, :string
    field :last_seen_at, :utc_datetime_usec
    field :disabled_at, :utc_datetime_usec
    field :failure_count, :integer, default: 0
    field :last_error, :string
    field :metadata, :map, default: %{}

    timestamps(inserted_at: :created_at, updated_at: false)
  end

  def changeset(device_token, attrs) do
    device_token
    |> cast(attrs, [
      :user_id,
      :token,
      :platform,
      :provider,
      :user_type,
      :interests,
      :locale,
      :device_id,
      :last_seen_at,
      :disabled_at,
      :failure_count,
      :last_error,
      :metadata
    ])
    |> validate_required([:user_id, :token, :platform])
    |> validate_inclusion(:platform, @platforms)
    |> validate_inclusion(:provider, @providers)
    |> update_change(:interests, fn values ->
      values
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
    end)
    |> unique_constraint(:token)
  end
end
