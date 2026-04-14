import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values  = { content: String }
  static targets = ["button"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.contentValue)
      this.buttonTarget.textContent = "Copied!"
      setTimeout(() => { this.buttonTarget.textContent = "Copy" }, 2000)
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
      this.buttonTarget.textContent = "Copied!"
      setTimeout(() => { this.buttonTarget.textContent = "Copy" }, 2000)
    }
  }
}
