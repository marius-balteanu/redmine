import { Controller } from '@hotwired/stimulus'
import { get } from '@rails/request.js'

// Generic Stimulus controller for loading and appending remote HTML fragments.
// Supports replacing/removing a trigger element, appending to a container,
// and dispatching lifecycle events for listeners (such as selection trackers).
export default class extends Controller {
  static targets = ['trigger', 'container']
  static values = {
    afterLoadEvent: String,
    insertionPosition: { type: String, default: 'beforebegin' }
  }

  async load(event) {
    event.preventDefault()

    const trigger = event.currentTarget.closest('[data-load-more-target~="trigger"]') || event.currentTarget
    if (trigger.dataset.loading === 'true') {
      return
    }
    trigger.dataset.loading = 'true'

    try {
      const response = await get(event.currentTarget.href, { responseKind: 'html' })
      if (!response.ok) {
        return
      }

      const html = await response.html

      if (this.hasContainerTarget) {
        this.containerTarget.insertAdjacentHTML('beforeend', html)
      } else {
        trigger.insertAdjacentHTML(this.insertionPositionValue, html)
      }
      trigger.remove()

      this.dispatch('loaded', { detail: { html } })

      if (this.hasAfterLoadEventValue) {
        this.element.dispatchEvent(new CustomEvent(this.afterLoadEventValue, { bubbles: true }))
      }
    } finally {
      delete trigger.dataset.loading
    }
  }
}
