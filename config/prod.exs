import Config

# Configure your database
config :notification_service, NotificationService.Repo,
  username: System.get_env("DATABASE_USERNAME", "postgres"),
  password: System.get_env("DATABASE_PASSWORD", "postgres"),
  hostname: System.get_env("DATABASE_HOSTNAME", "localhost"),
  database: System.get_env("DATABASE_NAME", "notification_service_prod"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: System.get_env("DATABASE_SSL") == "true"

# Configure the web endpoint
config :notification_service, NotificationServiceWeb.Endpoint,
  url: [host: System.get_env("HOST", "localhost"), port: 80],
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  server: true

# Configure Oban for production
config :oban,
  repo: NotificationService.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 30}, # 30 days
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", NotificationService.Workers.NotificationCleanup}
     ]}
  ],
  queues: [default: 10, notifications: 50, fanout: 100]

# Configure logging
config :logger,
  level: :info,
  backends: [:console]

# Configure PubSub for clustering (if needed)
config :notification_service, NotificationService.PubSub,
  adapter: Phoenix.PubSub.PG2,
  name: NotificationService.PubSub