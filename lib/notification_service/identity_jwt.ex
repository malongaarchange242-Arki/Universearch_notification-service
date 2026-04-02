defmodule NotificationService.IdentityJwt do
  @moduledoc """
  Verifies access tokens issued by identity-service.
  Expected algorithm: HS256 using the shared JWT_SECRET.
  """

  @spec verify(binary()) :: {:ok, map()} | :error
  def verify(token) when is_binary(token) do
    with {:ok, secret} <- fetch_secret(),
         {:ok, header_b64, payload_b64, signature_b64} <- split_token(token),
         {:ok, header} <- decode_json(header_b64),
         true <- header["alg"] == "HS256",
         true <- valid_signature?(header_b64, payload_b64, signature_b64, secret),
         {:ok, payload} <- decode_json(payload_b64),
         true <- valid_payload?(payload) do
      {:ok, payload}
    else
      _ -> :error
    end
  end

  def verify(_), do: :error

  defp fetch_secret do
    case System.get_env("JWT_SECRET") do
      secret when is_binary(secret) and byte_size(secret) > 0 -> {:ok, secret}
      _ -> :error
    end
  end

  defp split_token(token) do
    case String.split(token, ".") do
      [header_b64, payload_b64, signature_b64] -> {:ok, header_b64, payload_b64, signature_b64}
      _ -> :error
    end
  end

  defp decode_json(segment) do
    with {:ok, decoded} <- Base.url_decode64(segment, padding: false),
         {:ok, json} <- Jason.decode(decoded) do
      {:ok, json}
    else
      _ -> :error
    end
  end

  defp valid_signature?(header_b64, payload_b64, signature_b64, secret) do
    signing_input = header_b64 <> "." <> payload_b64

    expected_signature =
      :crypto.mac(:hmac, :sha256, secret, signing_input)
      |> Base.url_encode64(padding: false)

    Plug.Crypto.secure_compare(expected_signature, signature_b64)
  rescue
    _ -> false
  end

  defp valid_payload?(payload) when is_map(payload) do
    has_identity = is_binary(payload["id"]) and byte_size(payload["id"]) > 0
    not_expired = not expired?(payload["exp"])
    has_identity and not_expired
  end

  defp valid_payload?(_), do: false

  defp expired?(nil), do: false

  defp expired?(exp) when is_integer(exp) do
    System.system_time(:second) >= exp
  end

  defp expired?(_), do: true
end
