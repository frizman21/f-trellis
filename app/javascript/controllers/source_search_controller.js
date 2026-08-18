import { Controller } from "@hotwired/stimulus"

// A search field for picking a Source on the ontology's CRUD forms.
//
// Sources are global and a crawled deployment has thousands of them, so a
// select of every one is not an option. This queries /sources/search as you
// type and writes the chosen id into a hidden field, which is what the form
// actually submits.
//
// A blank field means "no source": the citation row is rejected server-side
// when the hidden id is empty, so clearing the box is how you cite nothing.
export default class extends Controller {
  static targets = ["query", "id", "results", "chosen"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  // Debounced, so typing a word is one request rather than one per letter.
  search() {
    if (this.timeout) clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.fetchResults(), 250)
  }

  async fetchResults() {
    const query = this.queryTarget.value.trim()

    // Typing again after choosing means the choice is being replaced, so the
    // stale id must not survive into the submit.
    this.clearChoice()

    if (query.length < 2) {
      this.renderResults([])
      return
    }

    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) throw new Error(response.statusText)
      this.renderResults(await response.json())
    } catch {
      // A failed lookup must not take the form down with it — the rest of the
      // record is still submittable, just without a source.
      this.renderMessage("Could not search sources.")
    }
  }

  renderResults(sources) {
    this.resultsTarget.innerHTML = ""
    if (sources.length === 0) return

    sources.forEach((source) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className = "list-group-item list-group-item-action text-start"
      item.dataset.action = "click->source-search#choose"
      item.dataset.sourceId = source.id
      item.dataset.sourceUrl = source.url
      item.innerHTML = `<div class="small text-truncate">${escapeHtml(source.url)}</div>` +
        (source.description
          ? `<div class="small text-muted text-truncate">${escapeHtml(source.description)}</div>`
          : "")
      this.resultsTarget.appendChild(item)
    })
  }

  renderMessage(text) {
    this.resultsTarget.innerHTML =
      `<div class="list-group-item small text-muted">${escapeHtml(text)}</div>`
  }

  choose(event) {
    const { sourceId, sourceUrl } = event.currentTarget.dataset
    this.idTarget.value = sourceId
    this.queryTarget.value = sourceUrl
    this.resultsTarget.innerHTML = ""
    if (this.hasChosenTarget) this.chosenTarget.textContent = sourceUrl
  }

  clearChoice() {
    this.idTarget.value = ""
    if (this.hasChosenTarget) this.chosenTarget.textContent = ""
  }
}

function escapeHtml(value) {
  const node = document.createElement("div")
  node.textContent = value == null ? "" : String(value)
  return node.innerHTML
}
