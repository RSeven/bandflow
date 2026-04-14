# Orchestrates all external API calls for a music record.
# Returns a hash of fetched fields; caller decides what to persist.
class MusicMetadataService
  Result = Struct.new(
    :spotify_track_id, :spotify_url,
    :youtube_url,
    :lyrics, :chords,
    :bpm, :key_name, :key_mode,
    keyword_init: true
  )

  def self.fetch(title:, artist:)
    # Run all external fetches; each returns nil on failure so nothing blocks.
    spotify_result = SpotifyService.new.fetch(title, artist)
    lyrics         = GeniusService.fetch_lyrics(title, artist)
    chords         = ChordsScraperService.fetch(title, artist)
    youtube_url    = YoutubeService.fetch_url(title, artist)

    Result.new(
      spotify_track_id: spotify_result&.track_id,
      spotify_url:      spotify_result&.track_url,
      youtube_url:      youtube_url,
      lyrics:           lyrics,
      chords:           chords,
      bpm:              spotify_result&.bpm,
      key_name:         spotify_result&.key_name,
      key_mode:         spotify_result&.key_mode
    )
  end
end
