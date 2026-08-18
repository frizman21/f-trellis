import { Controller } from "@hotwired/stimulus"

// Narrows the "relate to" list to the entities a chosen relationship type can
// actually end at.
//
// A relationship type declares the entity type at each of its ends, and the
// server rejects an edge that contradicts them. This is so the form does not
// offer a choice that is going to be rejected — it is convenience, not the
// check. Every option is restored before filtering, so changing the type twice
// does not leave the list permanently narrowed.
export default class extends Controller {
  static targets = ["type", "entity"]

  connect() {
    // The full list, kept aside because filtering removes options from the DOM.
    this.allOptions = Array.from(this.entityTarget.options).map((option) => option.cloneNode(true))
    this.filter()
  }

  filter() {
    const chosen = this.typeTarget.selectedOptions[0]
    const toTypeId = chosen ? chosen.dataset.toEntityTypeId : null
    const previous = this.entityTarget.value

    this.entityTarget.innerHTML = ""
    this.allOptions.forEach((option) => {
      const isPrompt = option.value === ""
      if (isPrompt || !toTypeId || option.dataset.entityTypeId === toTypeId) {
        this.entityTarget.appendChild(option.cloneNode(true))
      }
    })

    // Keep the selection if it survived the narrowing; otherwise fall back to
    // the prompt rather than silently selecting someone else's entity.
    const stillThere = Array.from(this.entityTarget.options).some((o) => o.value === previous)
    this.entityTarget.value = stillThere ? previous : ""
  }
}
