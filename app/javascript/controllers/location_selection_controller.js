import { Controller } from '@hotwired/stimulus'
import { patch } from '@rails/request.js'
export default class extends Controller {
  static values = { url: String, count: Number }
  async perform() {
    const body = new FormData(this.element)
    const response = await patch(this.urlValue, { body, responseKind: 'turbo-stream' })
    if (response.ok) this.countValue += 1
  }
}