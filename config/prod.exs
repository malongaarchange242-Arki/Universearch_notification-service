import Config

config :notification_service, NotificationService.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: System.get_env("DATABASE_SSL") == "true"

config :notification_service, NotificationServiceWeb.Endpoint,
  url: [host: System.get_env("HOST", "localhost"), port: 80],
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  server: true

config :notification_service, Oban,
  repo: NotificationService.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 30}
  ],
  queues: [default: 10, notifications: 50, fanout: 100, push_fanout: 50, push_delivery: 200]

config :logger,
  level: :info,
  backends: [:console]

config :notification_service, NotificationService.PubSub,
  adapter: Phoenix.PubSub.PG,
  name: NotificationService.PubSub
