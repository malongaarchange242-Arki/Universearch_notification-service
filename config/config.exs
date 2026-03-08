import Config

config :notification_service,
  ecto_repos: [NotificationService.Repo]

config :notification_service, NotificationService.Repo,
  database: "notification_service_dev.db"

config :oban,
  repo: NotificationService.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, notifications: 50, fanout: 100]

config :notification_service, NotificationServiceWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 4000],
  secret_key_base: "your secret key base",
  pubsub_server: NotificationService.PubSub

import_config "#{config_env()}.exs"