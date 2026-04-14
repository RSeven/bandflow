# Per-source metadata lookups for the music form.
# Each method returns a hash containing either fetched fields or an :error string.
class MusicMetadataService
  SOURCES = %w[spotify youtube lyrics chords].freeze

  def self.fetch(source:, title:, artist:)
    case source
    when "spotify" then fetch_spotify(title, artist)
    when "youtube" then fetch_youtube(title, artist)
    when "lyrics"  then fetch_lyrics(title, artist)
    when "chords"  then fetch_chords(title, artist)
    else { error: "Unknown source" }
    end
  end

  def self.fetch_spotify(title, artist)
    result = SpotifyService.new.fetch(title, artist)
    return { error: "No Spotify match found" } unless result

    {
      spotify_url:      result.track_url,
      spotify_track_id: result.track_id,
      bpm:              result.bpm,
      key_name:         result.key_name,
      key_mode:         result.key_mode
    }
  rescue => e
    Rails.logger.error("Spotify fetch error: #{e.message}")
    { error: "Spotify lookup failed" }
  end

  def self.fetch_youtube(title, artist)
    url = YoutubeService.fetch_url(title, artist)
    return { error: "No YouTube match found" } if url.blank?

    { youtube_url: url }
  rescue => e
    Rails.logger.error("YouTube fetch error: #{e.message}")
    { error: "YouTube lookup failed" }
  end

  def self.fetch_lyrics(title, artist)
    lyrics = GeniusService.fetch_lyrics(title, artist)
    return { error: "Lyrics not found on Genius" } if lyrics.blank?

    { lyrics: lyrics }
  rescue => e
    Rails.logger.error("Lyrics fetch error: #{e.message}")
    { error: "Lyrics lookup failed" }
  end

  def self.fetch_chords(title, artist)
    chords = ChordsScraperService.fetch(title, artist)
    return { error: "Chords not found on Cifra Club" } if chords.blank?

    { chords: chords }
  rescue => e
    Rails.logger.error("Chords fetch error: #{e.message}")
    { error: "Chords lookup failed" }
  end
end
