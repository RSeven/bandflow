import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this._timer = null
    this._submitted = false
    this._hasScheduledSubmit = false
    this._handleSubmit = this._handleSubmit.bind(this)
    this._handleSubmitEnd = this._handleSubmitEnd.bind(this)
    this._beforeFrameRender = this._beforeFrameRender.bind(this)
    this.element.addEventListener("submit", this._handleSubmit)
    document.addEventListener("turbo:submit-end", this._handleSubmitEnd)
    document.addEventListener("turbo:before-frame-render", this._beforeFrameRender)
    this._restoreFocus()
  }

  disconnect() {
    clearTimeout(this._timer)
    this.element.removeEventListener("submit", this._handleSubmit)
    document.removeEventListener("turbo:submit-end", this._handleSubmitEnd)
    document.removeEventListener("turbo:before-frame-render", this._beforeFrameRender)
  }

  submit() {
    clearTimeout(this._timer)
    this._hasScheduledSubmit = true
    this._storeFocus()
    this._timer = setTimeout(() => {
      if (!this.element.isConnected) return

      this._hasScheduledSubmit = false
      this.element.requestSubmit()
    }, this.delayValue)
  }

  clear(event) {
    event.preventDefault()

    this._comparableFields(this.element).forEach((field) => {
      if (field instanceof HTMLSelectElement) return
      if (field instanceof HTMLInputElement && (field.type === "checkbox" || field.type === "radio")) return

      field.value = ""
    })

    this.element.requestSubmit()
  }

  _handleSubmit() {
    this._submitted = true
    this._hasScheduledSubmit = false
    this._storeFocus()
  }

  _handleSubmitEnd(event) {
    if (event.target !== this.element) return
    if (event.detail.success) return

    this._submitted = false
  }

  _beforeFrameRender(event) {
    if (!this._submitted && !this._hasScheduledSubmit) return

    const frameId = this._targetFrameId()
    if (!frameId || event.target.id !== frameId) return

    const incomingForm = this._matchingIncomingForm(event.detail.newFrame)
    if (!incomingForm) return

    if (this._hasScheduledSubmit || this._formValuesDiffer(this.element, incomingForm)) {
      event.preventDefault()
      event.detail.render = () => {}
      if (event.detail.resume) event.detail.resume()
      this._submitted = false

      if (!this._hasScheduledSubmit) {
        this.submit()
        return
      }

      this._storeFocus()
      return
    }

    this._submitted = false
    this._storeFocus()
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

  _targetFrameId() {
    if (this.element.dataset.turboFrame) return this.element.dataset.turboFrame
    return this.element.closest("turbo-frame")?.id
  }

  _matchingIncomingForm(frame) {
    const currentSignature = this._formSignature(this.element)
    return Array.from(frame.querySelectorAll("form[data-controller~='auto-submit']"))
      .find((form) => this._formSignature(form) === currentSignature)
  }

  _formSignature(form) {
    return [
      form.method.toLowerCase(),
      new URL(form.action, window.location.href).pathname,
      this._comparableFields(form).map((field) => field.name).sort().join(",")
    ].join("|")
  }

  _formValuesDiffer(currentForm, incomingForm) {
    const incomingFields = new Map(this._comparableFields(incomingForm).map((field) => [field.name, field.value]))

    return this._comparableFields(currentForm).some((field) => {
      return incomingFields.get(field.name) !== field.value
    })
  }

  _comparableFields(form) {
    return Array.from(form.elements).filter((field) => {
      if (!field.name || field.disabled || field.type === "hidden") return false
      return field instanceof HTMLInputElement || field instanceof HTMLTextAreaElement || field instanceof HTMLSelectElement
    })
  }
}
