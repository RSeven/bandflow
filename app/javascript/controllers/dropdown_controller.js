import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._handleOutsideClick = this._handleOutsideClick.bind(this)
    this._handleKeydown = this._handleKeydown.bind(this)
    document.addEventListener("click", this._handleOutsideClick)
    document.addEventListener("keydown", this._handleKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this._handleOutsideClick)
    document.removeEventListener("keydown", this._handleKeydown)
  }

  _handleOutsideClick(e) {
    if (!this.element.contains(e.target)) this.element.open = false
  }

  _handleKeydown(e) {
    if (e.key === "Escape") this.element.open = false
  }
}
