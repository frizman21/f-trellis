import { Controller } from "@hotwired/stimulus"

// Shows a type's attributes on hover, using the Bootstrap popover already
// bundled with the app.
//
// A Stimulus controller rather than the DOMContentLoaded/turbo:load pattern in
// CLAUDE.md: a popover holds a DOM node and event listeners that have to be
// disposed when its trigger goes away, and disconnect() is exactly that hook.
// The documented pattern has no equivalent, which is how duplicate popovers and
// detached nodes accumulate under Turbo.
export default class extends Controller {
  connect() {
    if (!window.bootstrap) return

    this.popover = new window.bootstrap.Popover(this.element, {
      trigger: "hover focus",
      placement: "top",
      // The content is plain text set at render time, so there is no request on
      // hover and nothing to escape.
      customClass: "type-popover",
      container: "body"
    })
  }

  disconnect() {
    if (this.popover) {
      this.popover.dispose()
      this.popover = null
    }
  }
}
