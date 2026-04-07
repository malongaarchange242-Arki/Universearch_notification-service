import Config

config :notification_service,
  ecto_repos: [NotificationService.Repo]

config :notification_service, Oban,
  repo: NotificationService.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, notifications: 50, fanout: 100, push_fanout: 50, push_delivery: 200]

config :notification_service, :push_provider, NotificationService.Push.Providers.FCMV1

config :notification_service, NotificationService.Push.Providers.FCMV1,
  token_uri: "https://oauth2.googleapis.com/token",
  base_url: "https://fcm.googleapis.com",
  scope: "https://www.googleapis.com/auth/firebase.messaging",
  connect_timeout_ms: 5_000,
  recv_timeout_ms: 10_000

config :notification_service, NotificationServiceWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 4000],
  secret_key_base: "your secret key base",
  pubsub_server: NotificationService.PubSub,
  render_errors: [
    formats: [json: NotificationServiceWeb.ErrorJSON],
    layout: false
  ]

import_config "#{config_env()}.exs"
