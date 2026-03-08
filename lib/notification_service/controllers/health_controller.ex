defmodule NotificationService.Controllers.HealthController do
  use Phoenix.Controller, formats: [:json]

  def check(conn, _params) do
    json(conn, %{status: "ok"})
  end
end