import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hidden", "input", "tokens", "suggestions"]
  static values = { suggestionsUrl: String }

  connect() {
    this.labels = this._parseLabels(this.hiddenTarget.value)
    this._debounceTimer = null
    this._outsideClick = this._handleOutsideClick.bind(this)
    document.addEventListener("click", this._outsideClick)
    this._renderTokens()
    this._syncHidden()
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
  }

  search() {
    const value = this.inputTarget.value

    if (/[,\s]/.test(value)) {
      const parts = value.split(/[,\s]+/)
      parts.slice(0, -1).forEach((label) => this._addLabel(label))
      this.inputTarget.value = parts[parts.length - 1]
    }

    const query = this.inputTarget.value.trim()
    clearTimeout(this._debounceTimer)

    if (query.length === 0) {
      this._hideSuggestions()
      return
    }

    this._debounceTimer = setTimeout(() => this._fetchSuggestions(query), 200)
  }

  handleKeydown(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      this._addLabel(this.inputTarget.value)
      this.inputTarget.value = ""
      this._hideSuggestions()
      return
    }

    if (event.key === "Backspace" && this.inputTarget.value === "" && this.labels.length > 0) {
      this.labels.pop()
      this._renderTokens()
      this._syncHidden()
      return
    }

    if (event.key === "Escape") this._hideSuggestions()
  }

  commitOnBlur() {
    window.setTimeout(() => {
      this._addLabel(this.inputTarget.value)
      this.inputTarget.value = ""
      this._hideSuggestions()
    }, 120)
  }

  remove(event) {
    const label = event.currentTarget.dataset.label
    this.labels = this.labels.filter((item) => item !== label)
    this._renderTokens()
    this._syncHidden()
  }

  async _fetchSuggestions(query) {
    try {
      const response = await fetch(`${this.suggestionsUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json", "X-CSRF-Token": this._csrfToken() }
      })
      if (!response.ok) return

      const labels = await response.json()
      this._renderSuggestions(labels.filter((label) => !this.labels.includes(label)))
    } catch (error) {
      console.error("Label search error:", error)
    }
  }

  _renderSuggestions(labels) {
    if (labels.length === 0) {
      this._hideSuggestions()
      return
    }

    this.suggestionsTarget.innerHTML = labels.map((label) => `
      <li>
        <button type="button"
                data-label="${this._esc(label)}"
                class="w-full text-left px-3 py-2 text-sm text-zinc-200 hover:bg-zinc-700">
          ${this._esc(label)}
        </button>
      </li>
    `).join("")

    this.suggestionsTarget.querySelectorAll("button").forEach((button) => {
      button.addEventListener("mousedown", (event) => event.preventDefault())
      button.addEventListener("click", () => {
        this._addLabel(button.dataset.label)
        this.inputTarget.value = ""
        this._hideSuggestions()
        this.inputTarget.focus()
      })
    })

    this.suggestionsTarget.classList.remove("hidden")
  }

  _renderTokens() {
    this.tokensTarget.innerHTML = this.labels.map((label) => `
      <span class="music-label-badge ${this._badgeClass(label)}">
        ${this._esc(label)}
        <button type="button"
                data-action="label-input#remove"
                data-label="${this._esc(label)}"
                class="ml-1 text-zinc-500 hover:text-zinc-100"
                aria-label="Remove ${this._esc(label)}">x</button>
      </span>
    `).join("")
  }

  _addLabel(value) {
    const labels = this._parseLabels(value)
    labels.forEach((label) => {
      if (!this.labels.includes(label)) this.labels.push(label)
    })

    this._renderTokens()
    this._syncHidden()
  }

  _parseLabels(value) {
    return String(value || "")
      .split(/[,\s]+/)
      .map((label) => label.trim().toLowerCase())
      .filter((label) => label.length > 0)
  }

  _syncHidden() {
    this.hiddenTarget.value = this.labels.join(", ")
  }

  _hideSuggestions() {
    this.suggestionsTarget.classList.add("hidden")
    this.suggestionsTarget.innerHTML = ""
  }

  _handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this._hideSuggestions()
  }

  _csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  _badgeClass(label) {
    const total = String(label || "")
      .split("")
      .reduce((sum, char) => sum + char.charCodeAt(0), 0)
    return `music-label-badge--${total % 5}`
  }

  _esc(str) {
    return String(str ?? "")
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }
}
