import { Controller } from "@hotwired/stimulus"

// Copies its text: <button data-controller="clipboard" data-clipboard-text-value="…"
// data-action="clipboard#copy">Copy</button>, which says so for two seconds.
export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue).then(() => {
      const label = this.element.textContent
      this.element.textContent = "Copied!"
      setTimeout(() => (this.element.textContent = label), 2000)
    })
  }
}
