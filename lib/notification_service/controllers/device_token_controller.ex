defmodule NotificationService.Controllers.DeviceTokenController do
  use Phoenix.Controller, formats: [:json]

  alias NotificationService.Services.DeviceTokenService

  def register(conn, params) do
    current_user_id = conn.assigns[:current_user_id]
    device_token_params =
      case params do
        %{"device_token" => wrapped} when is_map(wrapped) -> wrapped
        bare when is_map(bare) -> bare
        _ -> %{}
      end

    case DeviceTokenService.register_device(current_user_id, device_token_params) do
      {:ok, device_token} ->
        conn
        |> put_status(:created)
        |> json(%{device_token: device_token})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
