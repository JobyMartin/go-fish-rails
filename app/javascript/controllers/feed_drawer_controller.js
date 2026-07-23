import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="feed-drawer"
export default class extends Controller {
  toggle() {
    document.body.classList.toggle("feed-open")
  }
}
