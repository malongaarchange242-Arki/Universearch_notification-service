defmodule NotificationService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        NotificationService.Repo,
        NotificationService.Push.AccessTokenCache,
        NotificationServiceWeb.Endpoint
      ]
      |> maybe_add_oban()

    opts = [strategy: :one_for_one, name: NotificationService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_oban(children) do
    if oban_enabled?() do
      List.insert_at(
        children,
        2,
        {Oban, Application.fetch_env!(:notification_service, Oban)}
      )
    else
      children
    end
  end

  defp oban_enabled? do
    System.get_env("OBAN_ENABLED", "true") != "false"
  end
end
