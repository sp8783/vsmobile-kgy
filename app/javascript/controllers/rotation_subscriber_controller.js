import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { rotationId: Number }

  connect() {
    console.log("RotationSubscriber connected for rotation:", this.rotationIdValue)

    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "RotationChannel", rotation_id: this.rotationIdValue },
      {
        connected: () => {
          console.log("Connected to RotationChannel")
        },

        disconnected: () => {
          console.log("Disconnected from RotationChannel")
        },

        received: (data) => {
          console.log("Received data:", data)

          if (data.type === 'rotation_updated') {
            // Reload the page to show updated information
            window.location.reload()
          }
        }
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.consumer) {
      this.consumer.disconnect()
    }
  }
}
