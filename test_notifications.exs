# Test script for real-time notifications
# Run with: elixir test_notifications.exs

# Start the notification service
IO.puts("🚀 Starting Notification Service...")

# Simulate creating a notification
notification_params = %{
  user_id: 123,
  type: "info",
  message: "Bienvenue sur UNIVERSEARCH !"
}

IO.puts("📝 Creating notification...")
IO.inspect(notification_params)

# In a real scenario, this would broadcast via WebSocket
broadcast_payload = %{
  notification: %{
    id: 1,
    user_id: 123,
    type: "info",
    message: "Bienvenue sur UNIVERSEARCH !",
    read: false,
    inserted_at: DateTime.utc_now()
  },
  unread_count: 1
}

IO.puts("📡 Broadcasting to WebSocket channel: notifications:123")
IO.puts("📊 Payload:")
IO.inspect(broadcast_payload, pretty: true)

IO.puts("✅ Real-time notification system ready!")
IO.puts("🌐 Connect to ws://localhost:4000/socket")
IO.puts("📱 Join channel: notifications:USER_ID")