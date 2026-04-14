import { Controller } from "@hotwired/stimulus"

// Handles the music form: iTunes autocomplete, metadata fetch
export default class extends Controller {
  static targets = [
    "searchInput", "suggestions",
    "title", "artist",
    "bpm", "keyName", "keyMode",
    "spotifyUrl", "youtubeUrl", "spotifyTrackId",
    "lyrics", "chords",
    "fetchStatus"
  ]

  static values = {
    searchUrl: String,
    fetchUrl: String
  }

  connect() {
    this._debounceTimer = null
    document.addEventListener("click", this._handleOutsideClick.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this._handleOutsideClick.bind(this))
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

  // ——— Metadata fetch ———

  async fetchMetadata() {
    const title  = this.titleTarget.value.trim()
    const artist = this.artistTarget.value.trim()

    if (!title || !artist) {
      this.fetchStatusTarget.textContent = "Enter title and artist first."
      return
    }

    this.fetchStatusTarget.textContent = "Fetching…"

    try {
      const resp = await fetch(this.fetchUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify({ title, artist })
      })

      if (!resp.ok) {
        this.fetchStatusTarget.textContent = "Fetch failed."
        return
      }

      const data = await resp.json()

      if (data.spotify_url)      this.spotifyUrlTarget.value     = data.spotify_url
      if (data.youtube_url)      this.youtubeUrlTarget.value     = data.youtube_url
      if (data.lyrics)           this.lyricsTarget.value         = data.lyrics
      if (data.chords)           this.chordsTarget.value         = data.chords
      if (data.bpm)              this.bpmTarget.value            = data.bpm
      if (data.key_name)         this.keyNameTarget.value        = data.key_name
      if (data.key_mode)         this.keyModeTarget.value        = data.key_mode
      if (data.spotify_track_id) this.spotifyTrackIdTarget.value = data.spotify_track_id

      const found = [
        data.spotify_url && "Spotify",
        data.youtube_url && "YouTube",
        data.chords      && "chords",
        data.lyrics      && "lyrics",
        data.bpm         && `${Math.round(data.bpm)} BPM`,
        data.key_name    && `${data.key_name} ${data.key_mode || ""}`
      ].filter(Boolean)

      this.fetchStatusTarget.textContent = found.length
        ? `Found: ${found.join(", ")}`
        : "No metadata found. You can fill in manually."

    } catch (e) {
      this.fetchStatusTarget.textContent = "Error: " + e.message
    }
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
