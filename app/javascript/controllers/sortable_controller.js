import { Controller } from "@hotwired/stimulus"

// Minimal drag-and-drop reordering for setlist items using the HTML5 Drag API
export default class extends Controller {
  static values = { url: String }

  connect() {
    this._dragSrc = null
    this._dropTarget = null
    this._dropPosition = null
    this._indicator = this._buildIndicator()

    this._boundDragStart = this._onDragStart.bind(this)
    this._boundDragOver = this._onDragOver.bind(this)
    this._boundDragLeave = this._onDragLeave.bind(this)
    this._boundDrop = this._onDrop.bind(this)
    this._boundDragEnd = this._onDragEnd.bind(this)

    this.element.addEventListener("dragstart", this._boundDragStart)
    this.element.addEventListener("dragover", this._boundDragOver)
    this.element.addEventListener("dragleave", this._boundDragLeave)
    this.element.addEventListener("drop", this._boundDrop)
    this.element.addEventListener("dragend", this._boundDragEnd)

    // Make items draggable
    this._refreshDraggable()
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this._boundDragStart)
    this.element.removeEventListener("dragover", this._boundDragOver)
    this.element.removeEventListener("dragleave", this._boundDragLeave)
    this.element.removeEventListener("drop", this._boundDrop)
    this.element.removeEventListener("dragend", this._boundDragEnd)
    this._clearIndicator()
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
    if (!target || target === this._dragSrc) return

    const rect = target.getBoundingClientRect()
    const position = e.clientY < rect.top + rect.height / 2 ? "before" : "after"
    this._showIndicator(target, position)
  }

  _onDragLeave(e) {
    const related = e.relatedTarget
    if (related && this.element.contains(related)) return

    this._clearIndicator()
  }

  _onDrop(e) {
    e.preventDefault()
    const target = this._dropTarget || e.target.closest("[data-id]")
    if (!target || target === this._dragSrc) return

    const position = this._dropPosition || "after"

    // Swap in DOM
    if (position === "after") {
      target.after(this._dragSrc)
    } else {
      target.before(this._dragSrc)
    }
    this._renumberItems()
    this._refreshDraggable()

    // Persist new order
    const id = this._dragSrc.dataset.id
    const newItems = Array.from(this.element.querySelectorAll("[data-id]"))
    const newPos   = newItems.indexOf(this._dragSrc)

    this._persist(id, newPos)
  }

  _onDragEnd() {
    this._dragSrc?.classList.remove("opacity-50")
    this._dragSrc = null
    this._clearIndicator()
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

  _buildIndicator() {
    const indicator = document.createElement("div")
    indicator.className = "pointer-events-none h-0"
    indicator.innerHTML = `
      <div class="h-0.5 rounded-full bg-amber-400 shadow-sm"></div>
      <div class="mt-1 flex justify-center">
        <div class="h-2 w-2 rounded-full bg-amber-400"></div>
      </div>
    `
    return indicator
  }

  _showIndicator(target, position) {
    if (this._dropTarget === target && this._dropPosition === position) return

    this._dropTarget = target
    this._dropPosition = position

    this._indicator.remove()

    if (position === "before") {
      target.before(this._indicator)
    } else {
      target.after(this._indicator)
    }
  }

  _clearIndicator() {
    this._dropTarget = null
    this._dropPosition = null
    this._indicator.remove()
  }

  _renumberItems() {
    let musicIndex = 0

    this.element.querySelectorAll("[data-id]").forEach((item, index) => {
      const position = item.querySelector('[data-sortable-role="position"]')
      if (position) position.textContent = index + 1

      const musicCounter = item.querySelector('[data-sortable-role="music-index"]')
      if (!musicCounter) return

      if (item.dataset.itemType === "Music") {
        musicIndex += 1
        musicCounter.textContent = `#${musicIndex}`
      }
    })
  }
}
