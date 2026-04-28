defmodule NotificationServiceWeb.Router do
  use Phoenix.Router

  pipeline :public do
    plug(:accepts, ["html", "json"])
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :authenticated_api do
    plug(:accepts, ["json"])
    plug(NotificationServiceWeb.Authenticate)
  end

  scope "/" do
    pipe_through(:public)

    get("/", NotificationService.Controllers.HealthController, :index)
    get("/health", NotificationService.Controllers.HealthController, :check)
  end

  scope "/api" do
    pipe_through(:api)

    get("/health", NotificationService.Controllers.HealthController, :check)
    post("/health", NotificationService.Controllers.HealthController, :check)
    get("/notifications/health", NotificationService.Controllers.HealthController, :check)
    post("/notifications", NotificationService.Controllers.NotificationController, :create)

    post(
      "/notifications/broadcast",
      NotificationService.Controllers.NotificationController,
      :broadcast
    )
  end

  scope "/api" do
    pipe_through(:authenticated_api)

    post(
      "/notifications/register-device",
      NotificationService.Controllers.DeviceTokenController,
      :register
    )

    get(
      "/notifications/unread-count/:user_id",
      NotificationService.Controllers.NotificationController,
      :unread_count
    )

    put(
      "/notifications/:id/mark-read",
      NotificationService.Controllers.NotificationController,
      :mark_as_read
    )

    delete("/notifications/:id", NotificationService.Controllers.NotificationController, :delete)
    delete("/notifications", NotificationService.Controllers.NotificationController, :delete_all)

    post(
      "/notifications/:id/events",
      NotificationService.Controllers.NotificationEventController,
      :create
    )

    get(
      "/notifications/:id/analytics",
      NotificationService.Controllers.NotificationEventController,
      :analytics
    )

    get("/notifications", NotificationService.Controllers.NotificationController, :index)
  end
end
