import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="feed-drawer"
export default class extends Controller {
  toggle() {
    const isOpen = document.body.classList.toggle("feed-open")
    document.body.dataset.feedOpen = isOpen
  }
}
