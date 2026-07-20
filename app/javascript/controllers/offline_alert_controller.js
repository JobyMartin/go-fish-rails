import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="offline-alert"
export default class extends Controller {
  static targets = ["status"]

  connect() {
    this.checkStatus()

    window.addEventListener("online", this.checkStatus.bind(this))
    window.addEventListener("offline", this.checkStatus.bind(this))
  }

  disconnect() {
    window.removeEventListener("online", this.checkStatus.bind(this))
    window.removeEventListener("offline", this.checkStatus.bind(this))
  }

  checkStatus() {
    if (navigator.onLine) {
      console.log("You are online!")
      this.element.classList.remove("alert--active")
    } else {
      console.log("You are offline.")
      this.element.classList.add("alert--active")
    }
  }
}
