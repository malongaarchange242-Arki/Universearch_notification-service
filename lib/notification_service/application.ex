defmodule NotificationService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [NotificationService.Repo]
      |> maybe_add_runtime_children()
      |> maybe_add_oban()

    opts = [strategy: :one_for_one, name: NotificationService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_runtime_children(children) do
    if running_migrations?() do
      children
    else
      children ++
        [
          NotificationService.Push.AccessTokenCache,
          NotificationServiceWeb.Endpoint
        ]
    end
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

  defp running_migrations? do
    System.get_env("RUNNING_MIGRATIONS", "false") in ["true", "1"]
  end
end
