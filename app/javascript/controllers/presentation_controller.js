import { Controller } from "@hotwired/stimulus"

// Controls the full-screen setlist presentation mode.
// Features: smooth roll scroll, next item navigation, elapsed timer, music counter.
export default class extends Controller {
  static targets = ["item", "content", "contentArea", "scrollMarker", "timer", "timerBtn", "counter", "nextBtn"]
  static values  = { musicCount: Number, tapToPause: String, tapToResume: String }

  connect() {
    this._currentIndex  = 0
    this._elapsed       = 0      // seconds
    this._timerRunning  = true
    this._interval      = null
    this._boundUpdateScrollMarker = this._updateScrollMarker.bind(this)

    this.contentAreaTarget.addEventListener("scroll", this._boundUpdateScrollMarker)
    window.addEventListener("resize", this._boundUpdateScrollMarker)

    this._loadItem(0)
    this._startTimer()
    // Keep screen awake if Wake Lock API is available
    this._requestWakeLock()
  }

  disconnect() {
    clearInterval(this._interval)
    this.contentAreaTarget.removeEventListener("scroll", this._boundUpdateScrollMarker)
    window.removeEventListener("resize", this._boundUpdateScrollMarker)
    this._releaseWakeLock()
  }

  // ——— Scroll controls ———

  scrollUp() {
    this._scrollByViewport(-1)
  }

  scrollDown() {
    this._scrollByViewport(1)
  }

  showChords() {
    this._setMusicView("chords")
  }

  showLyrics() {
    this._setMusicView("lyrics")
  }

  roll() {
    this.scrollDown()
  }

  // ——— Next item ———

  next() {
    const total = this.itemTargets.length
    if (this._currentIndex >= total - 1) return

    this._currentIndex++
    this._loadItem(this._currentIndex)
  }

  // ——— Load item by index ———

  _loadItem(index) {
    const templates = this.itemTargets
    if (index >= templates.length) return

    const tpl  = templates[index]
    const type = tpl.dataset.type

    // Fade out → swap content → fade in
    const content = this.contentTarget
    content.style.opacity    = "0"
    content.style.transition = "opacity 0.25s ease"

    setTimeout(() => {
      content.innerHTML = tpl.innerHTML
      // Reset scroll to top
      this.contentAreaTarget.scrollTo({ top: 0, behavior: "instant" })
      content.style.opacity = "1"
      this._updateScrollMarker()
    }, 250)

    // Update counter (only music items counted)
    if (type === "music") {
      const musicIdx = parseInt(tpl.dataset.musicIndex, 10) || 1
      this.counterTarget.textContent = `${musicIdx}/${this.musicCountValue}`
    } else {
      this.counterTarget.textContent = `— /${this.musicCountValue}`
    }

    // Dim Next button on last item
    const isLast = index >= templates.length - 1
    this.nextBtnTarget.disabled = isLast
    this.nextBtnTarget.classList.toggle("opacity-40", isLast)
  }

  // ——— Timer ———

  _startTimer() {
    this._interval = setInterval(() => {
      if (this._timerRunning) {
        this._elapsed++
        this._renderTimer()
      }
    }, 1000)
  }

  _renderTimer() {
    const m = Math.floor(this._elapsed / 60).toString().padStart(2, "0")
    const s = (this._elapsed % 60).toString().padStart(2, "0")
    this.timerTarget.textContent = `${m}:${s}`
  }

  toggleTimer() {
    this._timerRunning = !this._timerRunning
    const btn = this.timerBtnTarget.querySelector("span:last-child")
    if (btn) btn.textContent = this._timerRunning ? this.tapToPauseValue : this.tapToResumeValue
    this.timerTarget.classList.toggle("text-zinc-500", !this._timerRunning)
    this.timerTarget.classList.toggle("text-amber-400",  this._timerRunning)
  }

  _scrollByViewport(direction) {
    const area = this.contentAreaTarget
    const amount = Math.floor(area.clientHeight * 0.65) * direction
    area.scrollBy({ top: amount, behavior: "smooth" })
  }

  _setMusicView(view) {
    const contentAreas = this.contentTarget.querySelectorAll("[data-presentation-content]")
    if (contentAreas.length === 0) return

    contentAreas.forEach((area) => {
      area.classList.toggle("hidden", area.dataset.presentationContent !== view)
    })

    const buttons = this.contentTarget.querySelectorAll("[data-presentation-view]")
    buttons.forEach((button) => {
      const active = button.dataset.presentationView === view

      button.classList.toggle("border-amber-500/40", active)
      button.classList.toggle("bg-amber-500/20", active)
      button.classList.toggle("text-amber-300", active)
      button.classList.toggle("border-zinc-700", !active)
      button.classList.toggle("bg-zinc-900", !active)
      button.classList.toggle("text-zinc-300", !active)
    })
  }

  _updateScrollMarker() {
    if (!this.hasScrollMarkerTarget) return

    const area = this.contentAreaTarget
    const maxScrollTop = area.scrollHeight - area.clientHeight

    if (maxScrollTop <= 0) {
      this.scrollMarkerTarget.classList.add("hidden")
      return
    }

    const remainingDown = maxScrollTop - area.scrollTop

    if (remainingDown <= 0) {
      this.scrollMarkerTarget.classList.add("hidden")
      return
    }

    const previewOffset = Math.min(Math.floor(area.clientHeight * 0.65), remainingDown)
    this.scrollMarkerTarget.style.top = `${previewOffset}px`
    this.scrollMarkerTarget.classList.remove("hidden")
  }

  // ——— Wake Lock ———

  async _requestWakeLock() {
    try {
      if ("wakeLock" in navigator) {
        this._wakeLock = await navigator.wakeLock.request("screen")
      }
    } catch (_) {}
  }

  _releaseWakeLock() {
    this._wakeLock?.release()
  }
}
