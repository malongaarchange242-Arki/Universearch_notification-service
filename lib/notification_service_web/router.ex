defmodule NotificationServiceWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug NotificationServiceWeb.Authenticate
  end

  scope "/api" do
    pipe_through :api

    post "/health", NotificationService.Controllers.HealthController, :check
    post "/notifications", NotificationService.Controllers.NotificationController, :create
    post "/notifications/broadcast", NotificationService.Controllers.NotificationController, :broadcast
  end

  scope "/api" do
    pipe_through :authenticated_api

    post "/notifications/register-device", NotificationService.Controllers.DeviceTokenController, :register
    get "/notifications/unread-count/:user_id", NotificationService.Controllers.NotificationController, :unread_count
    put "/notifications/:id/mark-read", NotificationService.Controllers.NotificationController, :mark_as_read
    post "/notifications/:id/events", NotificationService.Controllers.NotificationEventController, :create
    get "/notifications/:id/analytics", NotificationService.Controllers.NotificationEventController, :analytics
    get "/notifications", NotificationService.Controllers.NotificationController, :index
  end
end
