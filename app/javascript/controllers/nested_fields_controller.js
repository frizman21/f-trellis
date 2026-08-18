import { Controller } from "@hotwired/stimulus"

// Appends another blank row to a form built from nested attributes.
//
// The row's markup lives in a <template> in the view rather than being built
// here, so it cannot drift from the server-rendered rows beside it — the usual
// failure of assembling markup in JavaScript.
//
// New rows are indexed from a counter that starts past the last server-rendered
// row, so a row added, then another, cannot collide on an index and have Rails
// treat the second as an edit of the first.
export default class extends Controller {
  static targets = ["list", "template"]
  static values = { startIndex: Number }

  connect() {
    this.index = this.startIndexValue
  }

  add(event) {
    event.preventDefault()

    const markup = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, this.index)
    this.index += 1
    this.listTarget.insertAdjacentHTML("beforeend", markup)
  }
}
