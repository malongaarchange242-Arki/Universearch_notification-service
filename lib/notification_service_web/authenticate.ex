defmodule NotificationServiceWeb.Authenticate do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, payload} <- NotificationService.IdentityJwt.verify(token),
         user_id when is_binary(user_id) <- payload["id"] do
      assign(conn, :current_user_id, user_id)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
        |> halt()
    end
  end
end
