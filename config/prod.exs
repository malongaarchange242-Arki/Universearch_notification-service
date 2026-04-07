import Config

ssl_enabled = System.get_env("DATABASE_SSL", "true") != "false"
server? =
  System.get_env("PHX_SERVER") in ["true", "1"] ||
    not is_nil(System.get_env("RELEASE_NAME"))
running_migrations? = System.get_env("RUNNING_MIGRATIONS") in ["true", "1"]
migration_pool_size = System.get_env("MIGRATION_POOL_SIZE") || "2"
migration_queue_target = System.get_env("MIGRATION_QUEUE_TARGET") || "60000"
repo_url =
  if running_migrations? and System.get_env("MIGRATION_DATABASE_URL") do
    System.get_env("MIGRATION_DATABASE_URL")
  else
    System.get_env("DATABASE_URL")
  end

config :notification_service, NotificationService.Repo,
  url: repo_url,
  pool_size:
    String.to_integer(
      System.get_env("POOL_SIZE") ||
        if(running_migrations?, do: migration_pool_size, else: "3")
    ),
  queue_target:
    String.to_integer(
      System.get_env("DB_QUEUE_TARGET") ||
        if(running_migrations?, do: migration_queue_target, else: "15000")
    ),
  queue_interval: String.to_integer(System.get_env("DB_QUEUE_INTERVAL") || "2000"),
  prepare: :unnamed,
  ssl: ssl_enabled

config :notification_service, NotificationServiceWeb.Endpoint,
  url: [host: System.get_env("HOST", "localhost"), port: 80],
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  server: server?

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
