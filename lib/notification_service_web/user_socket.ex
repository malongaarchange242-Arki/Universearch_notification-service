defmodule NotificationServiceWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "notifications:*", NotificationServiceWeb.NotificationChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case verify_user(token) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      :error ->
        :error
    end
  end

  # Deny connection if no token provided
  @impl true
  def connect(_params, _socket, _connect_info) do
    :error
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     NotificationServiceWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  # Verify JWT token and extract user_id
  # This uses Phoenix.Token for secure token verification
  defp verify_user(token) do
    try do
      # Verify the token with our secret key
      case Phoenix.Token.verify(NotificationServiceWeb.Endpoint, "user_socket_auth", token, max_age: 86400) do
        {:ok, user_id} when is_integer(user_id) ->
          {:ok, user_id}
        {:ok, _invalid_payload} ->
          :error
        {:error, _reason} ->
          :error
      end
    rescue
      # Handle any unexpected errors during token verification
      _error -> :error
    end
  end
end