import { Controller } from "@hotwired/stimulus"

// A flash message the visitor can close.
export default class extends Controller {
  close() {
    this.element.remove()
  }
}
