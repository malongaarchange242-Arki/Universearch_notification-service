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
  plug CORSPlug, origins: ["http://127.0.0.1:5502", "https://universearch-frontend.onrender.com/",  "http://localhost:5502", "http://127.0.0.1:5500", "http://localhost:5500", "http://localhost:3000", "http://127.0.0.1:3000", "http://localhost", "http://127.0.0.1"], methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"], headers: ["authorization", "content-type", "accept"], credentials: false

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Phoenix.json_library()

  plug NotificationServiceWeb.Router
end
