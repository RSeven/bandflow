import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this._timer = null
    this._restoreFocus()
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  submit() {
    clearTimeout(this._timer)
    this._storeFocus()
    this._timer = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  _storeFocus() {
    const input = document.activeElement
    if (!input || !this.element.contains(input)) return
    if (!(input instanceof HTMLInputElement || input instanceof HTMLTextAreaElement || input instanceof HTMLSelectElement)) return
    if (!input.name || input.type === "hidden") return

    sessionStorage.setItem(this._storageKey(), JSON.stringify({
      name: input.name,
      start: input.selectionStart,
      end: input.selectionEnd
    }))
  }

  _restoreFocus() {
    const saved = sessionStorage.getItem(this._storageKey())
    if (!saved) return

    sessionStorage.removeItem(this._storageKey())

    const { name, start, end } = JSON.parse(saved)
    if (!name) return

    const input = this.element.querySelector(`[name="${CSS.escape(name)}"]`)
    if (!input) return

    requestAnimationFrame(() => {
      input.focus()

      try {
        if (start != null && end != null) input.setSelectionRange(start, end)
      } catch (_) {}
    })
  }

  _storageKey() {
    return `auto-submit-focus:${window.location.pathname}`
  }
}
