# BandFlow — Claude Code Guide

## What this is
BandFlow is a Rails 8 web app for band management: repertoire, setlists, events, and member invitations. Authentication is home-rolled (no Devise).

## Tech stack
- **Ruby on Rails 8** (SQLite, Puma)
- **Stimulus** (Hotwire) for JS interactivity — see `app/javascript/controllers/`
- **Tailwind CSS** via CDN + custom dark theme (zinc palette, amber accent)
- **RSpec** + FactoryBot for tests — run with `bundle exec rspec`
- **HTTParty** + **Nokogiri** for external HTTP/scraping

## Key domains & files
| Domain | Model | Controller | Notable service |
|--------|-------|-----------|----------------|
| Bands | `app/models/band.rb` | `bands_controller.rb` | — |
| Musics | `app/models/music.rb` | `musics_controller.rb` | `MusicMetadataService` |
| Setlists | `app/models/setlist.rb` | `setlists_controller.rb` | — |
| Events | `app/models/event.rb` | `events_controller.rb` | — |
| Invitations | `app/models/invitation.rb` | `invitations_controller.rb` | — |

## External API integrations (`app/services/`)
| Service | Purpose | Env vars needed |
|---------|---------|----------------|
| `SpotifyService` | Track lookup via Spotify + BPM/key via SongBPM with Spotify audio-features fallback | `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` |
| `GeniusService` | Lyrics lookup via Genius API with `__PRELOADED_STATE__` parsing and container fallback | `GENIUS_ACCESS_TOKEN` |
| `ChordsScraperService` | Chord tabs from Cifra Club via slugged artist/title pages | — |
| `YoutubeService` | YouTube URL lookup | `YOUTUBE_API_KEY` |
| `ItunesSearchService` | Song autocomplete in the music form | — |
| `MusicMetadataService` | Orchestrates all of the above in one call | all of the above |

## Music form flow
1. User types in search box → iTunes autocomplete (`ItunesSearchService`)
2. User picks a result → Stimulus fires `fetchMetadata` → `POST /bands/:id/musics/fetch_metadata`
3. Controller calls `MusicMetadataService.fetch` → fans out to all external services in parallel
4. JS fills BPM, key, lyrics, chords, Spotify URL, YouTube URL fields

## Known issues (as of 2026-04-14)
1. **SongBPM dependency** — BPM/key now come from SongBPM first. If its search markup or anti-bot behavior changes, `SpotifyService` will fall back to Spotify only when `/v1/audio-features` is still available for the current app.
2. **Cifra Club slug matching** — `ChordsScraperService` depends on predictable artist/title slugs. Covers parentheticals and common suffix cleanup, but unusual release names may still miss.

## Running locally
```bash
bundle install
rails db:create db:migrate db:seed
rails server           # http://localhost:3000
bundle exec rspec      # full test suite
```

## Routes of interest
```
GET  /bands/:band_id/musics/search          # iTunes autocomplete (JSON)
POST /bands/:band_id/musics/fetch_metadata  # metadata fan-out (JSON)
```
