defmodule NotificationServiceWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api" do
    pipe_through :api

    post "/health", NotificationService.Controllers.HealthController, :check

    get "/notifications/unread-count/:user_id", NotificationService.Controllers.NotificationController, :unread_count
    put "/notifications/:id/mark-read", NotificationService.Controllers.NotificationController, :mark_as_read

    resources "/notifications", NotificationService.Controllers.NotificationController, only: [:index, :create]
  end
end