import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
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

  config :notification_service, NotificationService.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl:
      if ssl_enabled do
        ssl_opts
      else
        false
      end

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE is missing"

  config :notification_service, NotificationServiceWeb.Endpoint,
    server: true,
    http: [port: String.to_integer(System.get_env("PORT") || "4000")],
    secret_key_base: secret_key_base
end

config :notification_service, NotificationService.Push.Providers.FCMV1,
  project_id: System.get_env("FCM_PROJECT_ID"),
  credentials_json: System.get_env("FCM_SERVICE_ACCOUNT_JSON"),
  credentials_path: System.get_env("GOOGLE_APPLICATION_CREDENTIALS")
