// Example: Real-time notifications with JWT authentication (JavaScript)

// 1. Get JWT token from your authentication system
function getAuthToken() {
  // Replace with your actual token retrieval logic
  // This could be from localStorage, cookies, or your auth context
  return localStorage.getItem('auth_token') || 'your_jwt_token_here';
}

// 2. Connect to Phoenix Socket with JWT authentication
import { Socket } from "phoenix"

const socket = new Socket("/socket", {
  params: { token: getAuthToken() }
})

// Handle connection errors (invalid token, etc.)
socket.onError(() => {
  console.error("❌ WebSocket connection failed - invalid token?")
  // Redirect to login or refresh token
  // window.location.href = '/login'
})

socket.connect()

// 3. Join user's notification channel
const userId = getCurrentUserId() // Implement this based on your auth system
const channel = socket.channel(`notifications:${userId}`)

// 4. Handle real-time events
channel.on("new_notification", payload => {
  console.log("🔔 Nouvelle notification:", payload.notification)
  console.log("📊 Compteur non lues:", payload.unread_count)

  // Update UI immediately
  updateNotificationUI(payload.notification)
  updateUnreadCounter(payload.unread_count)
})

channel.on("notification_read", payload => {
  console.log("✅ Notification marquée comme lue:", payload.notification)
  updateUnreadCounter(payload.unread_count - 1)
})

// 5. Handle connection status
channel.join()
  .receive("ok", resp => {
    console.log("✅ Connecté aux notifications temps réel", resp)
    // Load initial data
    loadNotifications()
    loadUnreadCount()
  })
  .receive("error", resp => {
    console.log("❌ Échec de connexion aux notifications", resp)
    // Handle authentication errors
    if (resp.reason === "unauthorized") {
      console.error("🔐 Token invalide ou expiré")
      // Refresh token or redirect to login
    }
  })

// 6. Mark notification as read
function markAsRead(notificationId) {
  channel.push("mark_as_read", { notification_id: notificationId })
    .receive("ok", resp => {
      console.log("✅ Notification marquée comme lue", resp)
    })
    .receive("error", resp => {
      console.error("❌ Erreur lors du marquage comme lu", resp)
    })
}

// 7. Helper functions
function getCurrentUserId() {
  // Extract user ID from JWT token or your auth system
  // This is a placeholder - implement based on your auth
  return 123 // Replace with actual user ID
}

function updateNotificationUI(notification) {
  const notificationsList = document.getElementById("notifications-list")
  const notificationElement = createNotificationElement(notification)
  notificationsList.insertBefore(notificationElement, notificationsList.firstChild)

  // Show browser notification if permitted
  if (Notification.permission === "granted") {
    new Notification("Nouvelle notification", {
      body: notification.message,
      icon: "/favicon.ico"
    })
  }
}

function updateUnreadCounter(count) {
  const counter = document.getElementById("unread-counter")
  counter.textContent = count
  counter.style.display = count > 0 ? "block" : "none"

  // Update document title
  document.title = count > 0 ? `(${count}) Mon App` : "Mon App"
}

function createNotificationElement(notification) {
  const div = document.createElement("div")
  div.className = `notification ${notification.read ? "read" : "unread"}`
  div.innerHTML = `
    <div class="notification-type">${notification.type}</div>
    <div class="notification-message">${notification.message}</div>
    <div class="notification-time">${new Date(notification.inserted_at).toLocaleString()}</div>
    ${!notification.read ? '<button onclick="markAsRead(' + notification.id + ')">Marquer comme lu</button>' : ""}
  `
  return div
}

// 8. Load initial data
async function loadNotifications() {
  try {
    const response = await fetch(`/api/notifications?user_id=${userId}`, {
      headers: {
        'Authorization': `Bearer ${getAuthToken()}`,
        'Content-Type': 'application/json'
      }
    })
    const data = await response.json()

    data.notifications.forEach(notification => {
      updateNotificationUI(notification)
    })
  } catch (error) {
    console.error("Erreur lors du chargement des notifications:", error)
  }
}

async function loadUnreadCount() {
  try {
    const response = await fetch(`/api/notifications/unread-count/${userId}`, {
      headers: {
        'Authorization': `Bearer ${getAuthToken()}`,
        'Content-Type': 'application/json'
      }
    })
    const data = await response.json()

    updateUnreadCounter(data.unread_count)
  } catch (error) {
    console.error("Erreur lors du chargement du compteur:", error)
  }
}

// 9. Request notification permission
if ("Notification" in window) {
  Notification.requestPermission()
}

// Initialize
console.log("🚀 Initialisation du système de notifications temps réel...")
// loadNotifications() and loadUnreadCount() are called after channel join success

function updateUnreadCounter(count) {
  const counter = document.getElementById("unread-counter")
  counter.textContent = count
  counter.style.display = count > 0 ? "block" : "none"
}

function createNotificationElement(notification) {
  const div = document.createElement("div")
  div.className = `notification ${notification.read ? "read" : "unread"}`
  div.innerHTML = `
    <div class="notification-type">${notification.type}</div>
    <div class="notification-message">${notification.message}</div>
    <div class="notification-time">${new Date(notification.inserted_at).toLocaleString()}</div>
    ${!notification.read ? '<button onclick="markAsRead(' + notification.id + ')">Marquer comme lu</button>' : ""}
  `
  return div
}

// 7. Fetch initial data
async function loadNotifications() {
  const response = await fetch(`/api/notifications?user_id=${userId}`)
  const data = await response.json()

  data.notifications.forEach(notification => {
    updateNotificationUI(notification)
  })
}

async function loadUnreadCount() {
  const response = await fetch(`/api/notifications/unread-count/${userId}`)
  const data = await response.json()

  updateUnreadCounter(data.unread_count)
}

// Initialize
loadNotifications()
loadUnreadCount()