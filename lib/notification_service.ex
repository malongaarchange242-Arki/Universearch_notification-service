defmodule NotificationService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NotificationService.Repo,
      NotificationService.Push.AccessTokenCache,
      {Oban, Application.get_env(:oban, [])},
      NotificationServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: NotificationService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
