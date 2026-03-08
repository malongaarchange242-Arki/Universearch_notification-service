# Test script for JWT authentication in notification service
# Run with: elixir test_auth.exs

IO.puts("🔐 Testing JWT Authentication for Notification Service")
IO.puts("====================================================")

# Test token generation
user_id = 123
IO.puts("👤 Generating token for user #{user_id}...")

token = NotificationService.Auth.generate_token(user_id)
IO.puts("✅ Token generated: #{String.slice(token, 0, 50)}...")

# Test token verification
IO.puts("\n🔍 Verifying token...")
case NotificationService.Auth.verify_token(token) do
  {:ok, verified_user_id} ->
    IO.puts("✅ Token verified! User ID: #{verified_user_id}")
  :error ->
    IO.puts("❌ Token verification failed!")
end

# Test invalid token
IO.puts("\n🚫 Testing invalid token...")
case NotificationService.Auth.verify_token("invalid_token") do
  {:ok, _} ->
    IO.puts("❌ Invalid token was accepted!")
  :error ->
    IO.puts("✅ Invalid token correctly rejected")
end

# Test direct function calls instead of full socket simulation
IO.puts("\n🔧 Testing UserSocket verify_user function...")

# Test successful verification
case NotificationServiceWeb.UserSocket.verify_user(token) do
  {:ok, verified_user_id} ->
    IO.puts("✅ UserSocket.verify_user successful! User ID: #{verified_user_id}")
  :error ->
    IO.puts("❌ UserSocket.verify_user failed!")
end

# Test invalid token in verify_user
case NotificationServiceWeb.UserSocket.verify_user("invalid_token") do
  {:ok, _} ->
    IO.puts("❌ UserSocket.verify_user accepted invalid token!")
  :error ->
    IO.puts("✅ UserSocket.verify_user correctly rejected invalid token")
end

# Test channel authorization logic
IO.puts("\n📡 Testing channel authorization logic...")

# Simulate authenticated socket
authenticated_socket = %{
  assigns: %{user_id: 123}
}

# Test joining own channel
case NotificationServiceWeb.NotificationChannel.join("notifications:123", %{}, authenticated_socket) do
  {:ok, _} ->
    IO.puts("✅ Successfully authorized to join own notification channel")
  {:error, %{reason: reason}} ->
    IO.puts("❌ Failed to join own channel: #{reason}")
end

# Test joining another user's channel (should fail)
case NotificationServiceWeb.NotificationChannel.join("notifications:456", %{}, authenticated_socket) do
  {:ok, _} ->
    IO.puts("❌ SECURITY ISSUE: Authorized to join another user's channel!")
  {:error, %{reason: "unauthorized"}} ->
    IO.puts("✅ Correctly rejected joining another user's channel")
end

IO.puts("\n🎉 JWT Authentication tests completed!")
IO.puts("\n📖 Usage in Frontend:")
IO.puts("""
import { Socket } from "phoenix"

// Get JWT token from your auth system
const token = getAuthToken()

const socket = new Socket("/socket", {
  params: { token: token }
})

socket.connect()

const channel = socket.channel("notifications:USER_ID")
channel.join()
  .receive("ok", () => console.log("Connected to notifications"))
  .receive("error", () => console.log("Authentication failed"))
""")