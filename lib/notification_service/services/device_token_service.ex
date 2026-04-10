defmodule NotificationService.Services.DeviceTokenService do
  import Ecto.Query

  alias NotificationService.Models.DeviceToken
  alias NotificationService.Repo

  def register_device(user_id, attrs) do
    params =
      attrs
      |> normalize_attrs()
      |> Map.put(:user_id, user_id)
      |> Map.put_new(:last_seen_at, utc_now_usec())
      |> Map.put(:disabled_at, nil)

    %DeviceToken{}
    |> DeviceToken.changeset(params)
    |> Repo.insert(
      on_conflict: [
        set: [
          user_id: user_id,
          provider: Map.get(params, :provider, "fcm"),
          platform: Map.get(params, :platform),
          user_type: Map.get(params, :user_type),
          interests: Map.get(params, :interests, []),
          locale: Map.get(params, :locale),
          device_id: Map.get(params, :device_id),
          metadata: Map.get(params, :metadata, %{}),
          last_seen_at: Map.get(params, :last_seen_at),
          disabled_at: nil,
          failure_count: 0,
          last_error: nil,
          created_at: utc_now_usec()
        ]
      ],
      conflict_target: :token,
      returning: true
    )
  end

  def get_user_tokens(user_id) do
    Repo.all(from dt in DeviceToken, where: dt.user_id == ^user_id)
  end

  def get_active_user_tokens(user_id) do
    Repo.all(
      from dt in DeviceToken,
        where: dt.user_id == ^user_id and is_nil(dt.disabled_at)
    )
  end

  def get_active_token(id) do
    Repo.one(
      from dt in DeviceToken,
        where: dt.id == ^id and is_nil(dt.disabled_at)
    )
  end

  def disable_token(%DeviceToken{} = device_token, reason) do
    failure_count = Map.get(device_token, :failure_count, 0)

    device_token
    |> DeviceToken.changeset(%{
      disabled_at: utc_now_usec(),
      failure_count: failure_count + 1,
      last_error: inspect(reason)
    })
    |> Repo.update()
  end

  def mark_success(%DeviceToken{} = device_token) do
    device_token
    |> DeviceToken.changeset(%{
      last_seen_at: utc_now_usec(),
      failure_count: 0,
      last_error: nil
    })
    |> Repo.update()
  end

  def list_recipient_user_ids(filters \\ %{}) do
    try do
      filters = normalize_map(filters)

      DeviceToken
      |> where([dt], is_nil(dt.disabled_at))
      |> maybe_filter(:user_type, filters["user_type"])
      |> maybe_filter_platforms(filters["platforms"])
      |> maybe_filter_interests(filters["interests"])
      |> select([dt], dt.user_id)
      |> distinct(true)
      |> Repo.all()
    rescue
      e in Ecto.QueryError ->
        IO.error("Database query error in list_recipient_user_ids: #{inspect(e)}")
        []

      e ->
        IO.error("Unexpected error in list_recipient_user_ids: #{inspect(e)}")
        []
    end
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)

      {key, value}, acc when is_binary(key) ->
        case key do
          "token" -> Map.put(acc, :token, value)
          "platform" -> Map.put(acc, :platform, value)
          "provider" -> Map.put(acc, :provider, value)
          "user_id" -> Map.put(acc, :user_id, value)
          "user_type" -> Map.put(acc, :user_type, value)
          "interests" -> Map.put(acc, :interests, List.wrap(value))
          "locale" -> Map.put(acc, :locale, value)
          "device_id" -> Map.put(acc, :device_id, value)
          "last_seen_at" -> Map.put(acc, :last_seen_at, normalize_datetime(value))
          "metadata" -> Map.put(acc, :metadata, normalize_map(value))
          _ -> acc
        end
    end)
  end

  defp normalize_attrs(_attrs), do: %{}

  defp normalize_map(value) when is_map(value) do
    Enum.into(value, %{}, fn
      {key, nested_value} when is_atom(key) -> {Atom.to_string(key), nested_value}
      {key, nested_value} -> {to_string(key), nested_value}
    end)
  end

  defp normalize_map(_value), do: %{}

  defp normalize_datetime(%DateTime{} = value), do: value

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp normalize_datetime(_value), do: nil

  defp utc_now_usec do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, _field, ""), do: query

  defp maybe_filter(query, field, value) do
    where(query, [dt], field(dt, ^field) == ^to_string(value))
  end

  defp maybe_filter_platforms(query, values) when is_list(values) and values != [] do
    normalized = Enum.map(values, &to_string/1)
    where(query, [dt], dt.platform in ^normalized)
  end

  defp maybe_filter_platforms(query, _values), do: query

  defp maybe_filter_interests(query, values) when is_list(values) and values != [] do
    normalized = Enum.map(values, &to_string/1)
    where(query, [dt], fragment("? && ?", dt.interests, ^normalized))
  end

  defp maybe_filter_interests(query, _values), do: query
end
