defmodule NotificationServiceWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :notification_service

  socket "/socket", NotificationServiceWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: :notification_service,
    gzip: false,
    only: ~w(images)

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Phoenix.json_library()

  plug NotificationServiceWeb.Router
end
