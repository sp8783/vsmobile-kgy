import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "subscribeButton", "unsubscribeButton", "unsupportedMessage"]
  static values = {
    subscribed: Boolean,
    vapidPublicKey: String
  }

  async connect() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      this.showUnsupported()
      return
    }

    await this.fetchVapidPublicKey()
    await this.checkSubscriptionStatus()
  }

  async fetchVapidPublicKey() {
    try {
      const response = await fetch("/vapid_public_key")
      const data = await response.json()
      this.vapidPublicKeyValue = data.vapid_public_key
    } catch (error) {
      console.error("Failed to fetch VAPID public key:", error)
    }
  }

  async checkSubscriptionStatus() {
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      this.subscribedValue = !!subscription
      this.updateUI()
    } catch (error) {
      console.error("Failed to check subscription status:", error)
    }
  }

  async subscribe() {
    try {
      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        this.showPermissionDenied()
        return
      }

      const registration = await navigator.serviceWorker.ready

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
      })

      await this.saveSubscriptionToServer(subscription)

      this.subscribedValue = true
      this.updateUI()
      this.showMessage("プッシュ通知を有効化しました", "success")
    } catch (error) {
      console.error("Failed to subscribe:", error)
      this.showMessage("プッシュ通知の有効化に失敗しました", "error")
    }
  }

  async unsubscribe() {
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      if (subscription) {
        await subscription.unsubscribe()
        await this.removeSubscriptionFromServer()
      }

      this.subscribedValue = false
      this.updateUI()
      this.showMessage("プッシュ通知を無効化しました", "success")
    } catch (error) {
      console.error("Failed to unsubscribe:", error)
      this.showMessage("プッシュ通知の無効化に失敗しました", "error")
    }
  }

  async saveSubscriptionToServer(subscription) {
    const key = subscription.getKey("p256dh")
    const auth = subscription.getKey("auth")

    const response = await fetch("/push_subscriptions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        push_subscription: {
          endpoint: subscription.endpoint,
          p256dh_key: this.arrayBufferToBase64(key),
          auth_key: this.arrayBufferToBase64(auth)
        }
      })
    })

    if (!response.ok) {
      throw new Error("Failed to save subscription to server")
    }

    return response.json()
  }

  async removeSubscriptionFromServer() {
    const response = await fetch("/push_subscriptions/unsubscribe_all", {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      }
    })

    if (!response.ok) {
      throw new Error("Failed to remove subscription from server")
    }
  }

  updateUI() {
    if (this.hasSubscribeButtonTarget && this.hasUnsubscribeButtonTarget) {
      if (this.subscribedValue) {
        this.subscribeButtonTarget.classList.add("hidden")
        this.unsubscribeButtonTarget.classList.remove("hidden")
      } else {
        this.subscribeButtonTarget.classList.remove("hidden")
        this.unsubscribeButtonTarget.classList.add("hidden")
      }
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.subscribedValue
        ? "このデバイスでプッシュ通知が有効です"
        : "このデバイスでプッシュ通知が無効です"
      this.statusTarget.className = this.subscribedValue
        ? "text-sm text-green-600"
        : "text-sm text-gray-500"
    }
  }

  showUnsupported() {
    if (this.hasUnsupportedMessageTarget) {
      this.unsupportedMessageTarget.classList.remove("hidden")
    }
    if (this.hasSubscribeButtonTarget) {
      this.subscribeButtonTarget.classList.add("hidden")
    }
    if (this.hasUnsubscribeButtonTarget) {
      this.unsubscribeButtonTarget.classList.add("hidden")
    }
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "このブラウザはプッシュ通知に対応していません"
      this.statusTarget.className = "text-sm text-yellow-600"
    }
  }

  showPermissionDenied() {
    this.showMessage("通知の許可が必要です。ブラウザの設定を確認してください。", "error")
  }

  showMessage(message, type) {
    if (this.hasStatusTarget) {
      const originalText = this.statusTarget.textContent
      const originalClass = this.statusTarget.className

      this.statusTarget.textContent = message
      this.statusTarget.className = type === "success"
        ? "text-sm text-green-600 font-medium"
        : "text-sm text-red-600 font-medium"

      setTimeout(() => {
        this.updateUI()
      }, 3000)
    }
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding)
      .replace(/-/g, "+")
      .replace(/_/g, "/")

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }
    return outputArray
  }

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    return window.btoa(binary)
  }
}
