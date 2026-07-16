import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!this.element.open) this.open()
  }

  disconnect() {
    this.close()
  }

  open() {
    setTimeout(()=> this.element.show(), 0)
  }

  close() {
    this.element.close()
  }
}
