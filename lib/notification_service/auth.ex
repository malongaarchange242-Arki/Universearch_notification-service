defmodule NotificationService.Auth do
  @moduledoc """
  Authentication helpers for JWT token generation and verification.
  Used for WebSocket authentication in the notification service.
  """

  @doc """
  Generates a JWT token for a user that can be used for WebSocket authentication.

  ## Examples

      iex> NotificationService.Auth.generate_token(123)
      "SFMyNTY.g2gDbQAA..."

  """
  def generate_token(user_id) when is_integer(user_id) do
    Phoenix.Token.sign(NotificationServiceWeb.Endpoint, "user_socket_auth", user_id)
  end

  @doc """
  Verifies a JWT token and returns the user_id if valid.

  ## Examples

      iex> token = NotificationService.Auth.generate_token(123)
      iex> NotificationService.Auth.verify_token(token)
      {:ok, 123}

      iex> NotificationService.Auth.verify_token("invalid_token")
      :error

  """
  def verify_token(token) do
    try do
      case Phoenix.Token.verify(NotificationServiceWeb.Endpoint, "user_socket_auth", token, max_age: 86400) do
        {:ok, user_id} when is_integer(user_id) ->
          {:ok, user_id}
        _ ->
          :error
      end
    rescue
      _error -> :error
    end
  end

  @doc """
  Generates a token for testing purposes with a longer expiration.

  ## Examples

      iex> NotificationService.Auth.generate_test_token(456)
      "SFMyNTY.g2gDbQAA..."

  """
  def generate_test_token(user_id) do
    # For testing, use a longer max_age (30 days)
    Phoenix.Token.sign(NotificationServiceWeb.Endpoint, "user_socket_auth", user_id, max_age: 30 * 24 * 3600)
  end
end