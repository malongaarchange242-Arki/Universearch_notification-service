defmodule NotificationService.Push.Credentials do
  @moduledoc false

  @required_fields ~w(project_id client_email private_key token_uri)

  def load do
    config = Application.get_env(:notification_service, NotificationService.Push.Providers.FCMV1, [])

    with {:ok, raw_credentials} <- load_raw_credentials(config),
         {:ok, decoded} <- Jason.decode(raw_credentials),
         normalized <- normalize_credentials(decoded, config),
         :ok <- validate_credentials(normalized) do
      {:ok, normalized}
    end
  end

  defp load_raw_credentials(config) do
    credentials_json = Keyword.get(config, :credentials_json)
    credentials_path = Keyword.get(config, :credentials_path)

    cond do
      is_binary(credentials_json) and String.trim(credentials_json) != "" ->
        {:ok, credentials_json}

      is_binary(credentials_path) and String.trim(credentials_path) != "" ->
        File.read(credentials_path)

      true ->
        {:error, :missing_service_account_credentials}
    end
  end

  defp normalize_credentials(decoded, config) do
    decoded
    |> maybe_put("project_id", Keyword.get(config, :project_id))
    |> maybe_put("token_uri", Keyword.get(config, :token_uri))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put_new(map, key, value)

  defp validate_credentials(credentials) do
    missing_fields =
      Enum.filter(@required_fields, fn field ->
        value = Map.get(credentials, field)
        not (is_binary(value) and String.trim(value) != "")
      end)

    case missing_fields do
      [] -> :ok
      _ -> {:error, {:invalid_service_account_credentials, missing_fields}}
    end
  end
end
