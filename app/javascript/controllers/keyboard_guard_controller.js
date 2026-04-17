import { Controller } from "@hotwired/stimulus"

const ANDROID_APP_UA = "BandFlow Android"
const KEYBOARD_OPEN_THRESHOLD = 120
const EDGE_PADDING = 20
const FALLBACK_BOTTOM_SPACE = 360

export default class extends Controller {
  connect() {
    if (!this.enabled) return

    window.bandflowKeyboardGuard = this

    this.activeField = null
    this.syncTimer = null
    this.blurTimer = null

    this.boundFocusIn = this.handleFocusIn.bind(this)
    this.boundFocusOut = this.handleFocusOut.bind(this)
    this.boundViewportChange = this.handleViewportChange.bind(this)

    this.element.addEventListener("focusin", this.boundFocusIn)
    this.element.addEventListener("focusout", this.boundFocusOut)
    window.visualViewport.addEventListener("resize", this.boundViewportChange)
    window.visualViewport.addEventListener("scroll", this.boundViewportChange)

    this.syncViewportState()
  }

  disconnect() {
    if (!this.enabled) return

    this.element.removeEventListener("focusin", this.boundFocusIn)
    this.element.removeEventListener("focusout", this.boundFocusOut)
    window.visualViewport.removeEventListener("resize", this.boundViewportChange)
    window.visualViewport.removeEventListener("scroll", this.boundViewportChange)

    clearTimeout(this.syncTimer)
    clearTimeout(this.blurTimer)
    this.element.classList.remove("keyboard-guard-active")
    this.element.style.removeProperty("--keyboard-guard-offset")
  }

  handleFocusIn(event) {
    if (!this.isEditable(event.target)) return

    clearTimeout(this.blurTimer)
    this.activeField = event.target
    this.activateGuard()
    this.scheduleSync(250)
    this.scheduleSync(700)
  }

  handleFocusOut() {
    this.blurTimer = setTimeout(() => {
      if (this.isEditable(document.activeElement)) return

      this.activeField = null
      this.element.classList.remove("keyboard-guard-active")
      this.element.style.removeProperty("--keyboard-guard-offset")
    }, 150)
  }

  handleViewportChange() {
    if (this.activeField) {
      this.activateGuard()
      this.scheduleSync(60)
    }
  }

  scheduleSync(delay) {
    clearTimeout(this.syncTimer)
    this.syncTimer = setTimeout(() => this.ensureFieldIsVisible(), delay)
  }

  syncViewportState() {
    const keyboardOffset = this.keyboardOffset
    this.element.style.setProperty("--keyboard-guard-offset", `${keyboardOffset}px`)
    this.element.classList.toggle("keyboard-guard-active", keyboardOffset > KEYBOARD_OPEN_THRESHOLD)
  }

  activateGuard() {
    const viewportHeight = window.visualViewport?.height ?? window.innerHeight
    const bottomSpace = Math.max(
      this.keyboardOffset + 96,
      Math.round(viewportHeight * 0.45),
      FALLBACK_BOTTOM_SPACE
    )

    this.element.style.setProperty("--keyboard-guard-offset", `${bottomSpace}px`)
    this.element.classList.add("keyboard-guard-active")
  }

  ensureFieldIsVisible() {
    if (!this.activeField?.isConnected) return

    const viewport = window.visualViewport
    const rect = this.activeField.getBoundingClientRect()
    const scrollingElement = document.scrollingElement || document.documentElement
    const viewportHeight = viewport?.height ?? window.innerHeight
    const targetTop = viewportHeight * 0.3
    const nextScrollTop = scrollingElement.scrollTop + rect.top - targetTop - EDGE_PADDING

    scrollingElement.scrollTo({
      top: Math.max(0, nextScrollTop),
      behavior: "auto"
    })

    this.activeField.scrollIntoView({
      block: "center",
      inline: "nearest",
      behavior: "auto"
    })

    const adjustedRect = this.activeField.getBoundingClientRect()
    const visibleBottom = (viewport?.offsetTop ?? 0) + viewportHeight - EDGE_PADDING
    if (adjustedRect.bottom > visibleBottom) {
      scrollingElement.scrollBy({
        top: adjustedRect.bottom - visibleBottom + EDGE_PADDING,
        behavior: "auto"
      })
    }
  }

  isEditable(target) {
    if (!(target instanceof HTMLElement)) return false

    if (target instanceof HTMLInputElement) {
      return target.type !== "hidden" && !target.disabled && !target.readOnly
    }

    if (target instanceof HTMLTextAreaElement) {
      return !target.disabled && !target.readOnly
    }

    if (target instanceof HTMLSelectElement) {
      return !target.disabled
    }

    return target.isContentEditable
  }

  get keyboardOffset() {
    const viewport = window.visualViewport
    if (!viewport) return 0

    return Math.max(0, Math.round(window.innerHeight - (viewport.height + viewport.offsetTop)))
  }

  get enabled() {
    return navigator.userAgent.includes(ANDROID_APP_UA) && "visualViewport" in window
  }
}
