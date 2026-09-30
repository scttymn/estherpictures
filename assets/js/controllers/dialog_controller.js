import { Controller } from "@hotwired/stimulus"

// Opens its <dialog> as a modal when the page shows it.
export default class extends Controller {
  connect() {
    if (!this.element.open) this.element.showModal()
  }
}
