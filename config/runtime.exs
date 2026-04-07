import Config

if config_env() == :prod do
  server? =
    System.get_env("PHX_SERVER") in ["true", "1"] ||
      not is_nil(System.get_env("RELEASE_NAME"))

  running_migrations? = System.get_env("RUNNING_MIGRATIONS") in ["true", "1"]
  migration_pool_size = System.get_env("MIGRATION_POOL_SIZE") || "2"
  migration_queue_target = System.get_env("MIGRATION_QUEUE_TARGET") || "60000"

  database_url =
    System.get_env("MIGRATION_DATABASE_URL")
      |> case do
        nil ->
          System.get_env("DATABASE_URL")

        migration_url when running_migrations? ->
          migration_url

        _ ->
          System.get_env("DATABASE_URL")
      end ||
      raise "DATABASE_URL is missing"

  ssl_enabled = System.get_env("DATABASE_SSL", "true") != "false"
  ssl_verify = System.get_env("DATABASE_SSL_VERIFY", "peer")
  ssl_ca_cert_path = System.get_env("DATABASE_SSL_CA_CERT_PATH")
  database_host = URI.parse(database_url).host

  ssl_opts =
    cond do
      !ssl_enabled ->
        []

      ssl_verify == "none" ->
        [verify: :verify_none]

      is_binary(ssl_ca_cert_path) and ssl_ca_cert_path != "" ->
        [
          verify: :verify_peer,
          cacertfile: ssl_ca_cert_path,
          server_name_indication: String.to_charlist(database_host || "localhost")
        ]

      true ->
        [
          verify: :verify_peer,
          cacerts: :public_key.cacerts_get(),
          server_name_indication: String.to_charlist(database_host || "localhost")
        ]
    end

  repo_ssl =
    if ssl_enabled do
      ssl_opts
    else
      false
    end

  config :notification_service, NotificationService.Repo,
    url: database_url,
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
    ssl: repo_ssl

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE is missing"

  port =
    case System.get_env("PORT") do
      nil -> 4000
      "" -> 4000
      value -> String.to_integer(value)
    end

  config :notification_service, NotificationServiceWeb.Endpoint,
    http: [
      ip: {0, 0, 0, 0},
      port: port,
      transport_options: []
    ],
    secret_key_base: secret_key_base

  if server? do
    config :notification_service, NotificationServiceWeb.Endpoint, server: true
  end
end

config :notification_service, NotificationService.Push.Providers.FCMV1,
  project_id: System.get_env("FCM_PROJECT_ID"),
  credentials_json: System.get_env("FCM_SERVICE_ACCOUNT_JSON"),
  credentials_path: System.get_env("GOOGLE_APPLICATION_CREDENTIALS"),
  notification_image_url:
    System.get_env("FCM_NOTIFICATION_IMAGE_URL") ||
      "https://universearch-notification-service.onrender.com/images/universearch-notification-logo.png"
