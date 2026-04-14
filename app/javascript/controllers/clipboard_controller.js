import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values  = { content: String, defaultLabel: String, copiedLabel: String }
  static targets = ["button"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.contentValue)
      this._setCopiedState()
    } catch (_) {
      // Fallback for non-HTTPS / older browsers
      const el = document.createElement("textarea")
      el.value = this.contentValue
      el.style.position = "fixed"
      el.style.opacity  = "0"
      document.body.appendChild(el)
      el.select()
      document.execCommand("copy")
      document.body.removeChild(el)
      this._setCopiedState()
    }
  }

  _setCopiedState() {
    this.buttonTarget.textContent = this.copiedLabelValue || "Copied!"
    setTimeout(() => { this.buttonTarget.textContent = this.defaultLabelValue || "Copy" }, 2000)
  }
}
