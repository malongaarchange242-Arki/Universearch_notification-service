defmodule NotificationService.Controllers.HealthController do
  use Phoenix.Controller
  import Plug.Conn

  def index(conn, _params) do
    send_resp(conn, 200, "notification-service:ok")
  end

  def check(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
