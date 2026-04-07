defmodule NotificationService.Models.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :user_id,
             :type,
             :title,
             :message,
             :data,
             :read,
             :delivery_types,
             :priority,
             :deep_link,
             :collapse_key,
             :silent,
             :campaign_type,
             :sponsor_id,
             :inserted_at,
             :updated_at
           ]}

  @priorities ["high", "normal"]
  @campaign_types ["transactional", "engagement", "sponsored", "system"]

  schema "notifications" do
    field :user_id, :string
    field :type, :string
    field :title, :string
    field :message, :string
    field :data, :map, default: %{}
    field :read, :boolean, default: false
    field :delivery_types, {:array, :string}, default: ["in_app", "push"]
    field :priority, :string, default: "high"
    field :deep_link, :string
    field :collapse_key, :string
    field :silent, :boolean, default: false
    field :campaign_type, :string, default: "transactional"
    field :sponsor_id, :string

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :user_id,
      :type,
      :title,
      :message,
      :data,
      :read,
      :delivery_types,
      :priority,
      :deep_link,
      :collapse_key,
      :silent,
      :campaign_type,
      :sponsor_id
    ])
    |> validate_required([:user_id, :type, :message])
    |> validate_delivery_types()
    |> validate_inclusion(:priority, @priorities)
    |> validate_inclusion(:campaign_type, @campaign_types)
  end

  defp validate_delivery_types(changeset) do
    allowed = ["in_app", "push"]

    changeset
    |> update_change(:delivery_types, fn values ->
      values
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
    end)
    |> validate_subset(:delivery_types, allowed)
  end
end
