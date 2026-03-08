import Config

config :notification_service, NotificationService.Repo,
  database: "notification_service_dev.db",
  show_sensitive_data_on_connection_error: true

config :notification_service, NotificationServiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: "dev-secret-key",
  watchers: []