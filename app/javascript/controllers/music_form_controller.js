import { Controller } from "@hotwired/stimulus"

// Handles the music form: iTunes autocomplete + parallel metadata fetch from Spotify / YouTube / Genius / Cifra Club.
export default class extends Controller {
  static targets = [
    "searchInput", "suggestions",
    "title", "artist",
    "bpm", "keyName", "keyMode",
    "spotifyUrl", "youtubeUrl", "spotifyTrackId",
    "lyrics", "chords",
    "fetchStatus", "fetchButton", "submit",
    "spotifyStatus", "youtubeStatus", "lyricsStatus", "chordsStatus"
  ]

  static values = {
    searchUrl: String,
    fetchUrl: String
  }

  connect() {
    this._debounceTimer = null
    this._outsideClick = this._handleOutsideClick.bind(this)
    document.addEventListener("click", this._outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
  }

  // ——— Autocomplete ———

  search() {
    const q = this.searchInputTarget.value.trim()
    clearTimeout(this._debounceTimer)

    if (q.length < 2) {
      this._hideSuggestions()
      return
    }

    this._debounceTimer = setTimeout(async () => {
      try {
        const resp = await fetch(`${this.searchUrlValue}?q=${encodeURIComponent(q)}`, {
          headers: { "Accept": "application/json", "X-CSRF-Token": this._csrfToken() }
        })
        if (!resp.ok) return
        const results = await resp.json()
        this._renderSuggestions(results)
      } catch (e) {
        console.error("Search error:", e)
      }
    }, 300)
  }

  _renderSuggestions(results) {
    const ul = this.suggestionsTarget

    if (results.length === 0) {
      this._hideSuggestions()
      return
    }

    ul.innerHTML = results.map(r => `
      <li data-track="${this._esc(r.track_name)}"
          data-artist="${this._esc(r.artist_name)}"
          class="flex items-center gap-3 px-3 py-2.5 hover:bg-zinc-700 cursor-pointer border-b border-zinc-700/50 last:border-0">
        ${r.artwork_url ? `<img src="${r.artwork_url}" class="w-10 h-10 rounded object-cover flex-shrink-0" />` : ""}
        <div class="min-w-0">
          <div class="text-sm font-medium truncate">${this._esc(r.track_name)}</div>
          <div class="text-xs text-zinc-400 truncate">${this._esc(r.artist_name)}</div>
        </div>
      </li>
    `).join("")

    ul.querySelectorAll("li").forEach(li => {
      li.addEventListener("click", () => this._selectSuggestion(li.dataset.track, li.dataset.artist))
    })

    ul.classList.remove("hidden")
  }

  _selectSuggestion(track, artist) {
    this.titleTarget.value  = track
    this.artistTarget.value = artist
    this.searchInputTarget.value = `${track} — ${artist}`
    this._hideSuggestions()
    // Auto-fetch all metadata as soon as the user picks a song
    this.fetchMetadata()
  }

  _hideSuggestions() {
    this.suggestionsTarget.classList.add("hidden")
    this.suggestionsTarget.innerHTML = ""
  }

  _handleOutsideClick(e) {
    if (!this.element.contains(e.target)) this._hideSuggestions()
  }

  // Show the fetch button whenever the user manually edits title or artist.
  // Programmatic .value = ... (used by autocomplete) does not fire `input`, so
  // the button stays hidden during the auto-fill → auto-fetch flow.
  onManualInput() {
    this.fetchButtonTarget.classList.remove("hidden")
  }

  // ——— Metadata fetch ———

  get _sources() {
    return {
      spotify: {
        label: "Spotify (BPM, key, URL)",
        shortLabel: "Spotify",
        statusTargets: () => this.spotifyStatusTargets,
        fields: () => [this.bpmTarget, this.keyNameTarget, this.keyModeTarget, this.spotifyUrlTarget],
        apply: (data) => {
          if (data.spotify_url)      this.spotifyUrlTarget.value     = data.spotify_url
          if (data.spotify_track_id) this.spotifyTrackIdTarget.value = data.spotify_track_id
          if (data.bpm != null)      this.bpmTarget.value            = data.bpm
          if (data.key_name)         this.keyNameTarget.value        = data.key_name
          if (data.key_mode)         this.keyModeTarget.value        = data.key_mode
        }
      },
      youtube: {
        label: "YouTube",
        shortLabel: "YouTube",
        statusTargets: () => this.youtubeStatusTargets,
        fields: () => [this.youtubeUrlTarget],
        apply: (data) => {
          if (data.youtube_url) this.youtubeUrlTarget.value = data.youtube_url
        }
      },
      lyrics: {
        label: "Lyrics (Genius)",
        shortLabel: "Lyrics",
        statusTargets: () => this.lyricsStatusTargets,
        fields: () => [this.lyricsTarget],
        apply: (data) => {
          if (data.lyrics) this.lyricsTarget.value = data.lyrics
        }
      },
      chords: {
        label: "Chords (Cifra Club)",
        shortLabel: "Chords",
        statusTargets: () => this.chordsStatusTargets,
        fields: () => [this.chordsTarget],
        apply: (data) => {
          if (data.chords) this.chordsTarget.value = data.chords
        }
      }
    }
  }

  async fetchMetadata() {
    const title  = this.titleTarget.value.trim()
    const artist = this.artistTarget.value.trim()

    if (!title || !artist) {
      this.fetchStatusTarget.textContent = "Enter title and artist first."
      return
    }

    if (this._fetching) return
    this._fetching = true
    this.fetchStatusTarget.textContent = ""
    if (this.hasSubmitTarget) this.submitTarget.disabled = true

    const tasks = Object.keys(this._sources).map(source =>
      this._fetchSource(source, title, artist)
    )

    try {
      await Promise.allSettled(tasks)
    } finally {
      this._fetching = false
      if (this.hasSubmitTarget) this.submitTarget.disabled = false
    }
  }

  async _fetchSource(sourceName, title, artist) {
    const source = this._sources[sourceName]
    this._setFieldsDisabled(source, true)
    this._renderStatus(source, "fetching", `Fetching ${source.label}…`)

    try {
      const resp = await fetch(this.fetchUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify({ source: sourceName, title, artist })
      })

      const data = resp.ok ? await resp.json() : { error: `request failed (HTTP ${resp.status})` }

      if (data.error) {
        this._renderStatus(source, "error", `${source.shortLabel}: ${data.error}`)
      } else {
        source.apply(data)
        this._renderStatus(source, "success", `${source.shortLabel} loaded.`)
      }
    } catch (e) {
      this._renderStatus(source, "error", `${source.shortLabel}: ${e.message}`)
    } finally {
      this._setFieldsDisabled(source, false)
    }
  }

  _setFieldsDisabled(source, disabled) {
    source.fields().forEach(el => { el.disabled = disabled })
  }

  _renderStatus(source, state, message) {
    const stateClasses = {
      fetching: "text-amber-400",
      success:  "text-emerald-400",
      error:    "text-red-400"
    }

    source.statusTargets().forEach(el => {
      el.classList.remove("hidden", "text-amber-400", "text-emerald-400", "text-red-400")
      el.classList.add("text-xs", stateClasses[state])
      el.dataset.state = state

      if (state === "fetching") {
        el.innerHTML =
          `<span class="inline-block w-2 h-2 rounded-full bg-amber-400 animate-pulse mr-1.5 align-middle"></span>` +
          this._esc(message)
      } else {
        el.textContent = message
      }
    })
  }

  _csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  _esc(str) {
    return String(str ?? "")
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }
}
