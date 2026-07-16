import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="auto-play"
export default class extends Controller {
  static targets = ['playButton']
  play() {
    this.playButtonTarget.click()
  }
}
