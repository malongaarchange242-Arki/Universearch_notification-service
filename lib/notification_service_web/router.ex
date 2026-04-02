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
  end

  scope "/api" do
    pipe_through :authenticated_api

    get "/notifications/unread-count/:user_id", NotificationService.Controllers.NotificationController, :unread_count
    put "/notifications/:id/mark-read", NotificationService.Controllers.NotificationController, :mark_as_read
    get "/notifications", NotificationService.Controllers.NotificationController, :index
  end
end
