import { Controller } from "@hotwired/stimulus"

// Minimal drag-and-drop reordering for setlist items using the HTML5 Drag API
export default class extends Controller {
  static values = { url: String }

  connect() {
    this._dragSrc = null
    this.element.addEventListener("dragstart",  this._onDragStart.bind(this))
    this.element.addEventListener("dragover",   this._onDragOver.bind(this))
    this.element.addEventListener("dragleave",  this._onDragLeave.bind(this))
    this.element.addEventListener("drop",       this._onDrop.bind(this))
    this.element.addEventListener("dragend",    this._onDragEnd.bind(this))

    // Make items draggable
    this._refreshDraggable()
  }

  _refreshDraggable() {
    this.element.querySelectorAll("[data-id]").forEach(el => {
      el.setAttribute("draggable", "true")
    })
  }

  _onDragStart(e) {
    this._dragSrc = e.target.closest("[data-id]")
    if (!this._dragSrc) return
    e.dataTransfer.effectAllowed = "move"
    this._dragSrc.classList.add("opacity-50")
  }

  _onDragOver(e) {
    e.preventDefault()
    e.dataTransfer.dropEffect = "move"
    const target = e.target.closest("[data-id]")
    if (target && target !== this._dragSrc) {
      target.classList.add("border-amber-500")
    }
  }

  _onDragLeave(e) {
    const target = e.target.closest("[data-id]")
    if (target) target.classList.remove("border-amber-500")
  }

  _onDrop(e) {
    e.preventDefault()
    const target = e.target.closest("[data-id]")
    if (!target || target === this._dragSrc) return

    target.classList.remove("border-amber-500")

    // Swap in DOM
    const items   = Array.from(this.element.querySelectorAll("[data-id]"))
    const fromIdx = items.indexOf(this._dragSrc)
    const toIdx   = items.indexOf(target)

    if (fromIdx < toIdx) {
      target.after(this._dragSrc)
    } else {
      target.before(this._dragSrc)
    }

    // Persist new order
    const id = this._dragSrc.dataset.id
    const newItems = Array.from(this.element.querySelectorAll("[data-id]"))
    const newPos   = newItems.indexOf(this._dragSrc)

    this._persist(id, newPos)
  }

  _onDragEnd() {
    this._dragSrc?.classList.remove("opacity-50")
    this._dragSrc = null
    this.element.querySelectorAll("[data-id]").forEach(el => el.classList.remove("border-amber-500"))
  }

  async _persist(itemId, position) {
    const url = this.urlValue.replace("/setlist_items", `/setlist_items/${itemId}`)
    try {
      await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify({ position })
      })
    } catch (e) {
      console.error("Reorder failed:", e)
    }
  }
}
