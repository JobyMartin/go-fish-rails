import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "play"]
  static values = { url: String, refreshInterval: Number }

  connect() {
    this.timerController = setInterval(() => {
      if (this.timer == null) this.startTimer()
    })
  }

  disconnect() {
    clearInterval(this.timerController)
  }

  startTimer() {
    let count = 10;

    this.timer = setInterval(() => {
      this.outputTarget.textContent = count;

      if (count > 0) {
        count--;
        this.outputTarget.textContent = count;
      } else {
        clearInterval(this.timer);
        this.timer = null
        this.dispatch('timer-over', {
          details: {autoPlay: true}
        })
      }
    }, 1000);
  }
}
