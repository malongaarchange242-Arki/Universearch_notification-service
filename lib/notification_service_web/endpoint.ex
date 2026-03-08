defmodule NotificationServiceWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :notification_service

  socket "/socket", NotificationServiceWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug NotificationServiceWeb.Router
end