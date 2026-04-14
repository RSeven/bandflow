class SpotifyService
  TOKEN_URL  = "https://accounts.spotify.com/api/token"
  SEARCH_URL = "https://api.spotify.com/v1/search"
  FEATURES_URL = "https://api.spotify.com/v1/audio-features"

  PITCH_CLASSES = %w[C C# D D# E F F# G G# A A# B].freeze

  Result = Struct.new(
    :track_id, :track_url,
    :bpm, :key_name, :key_mode,
    keyword_init: true
  )

  def initialize
    @client_id     = ENV["SPOTIFY_CLIENT_ID"]
    @client_secret = ENV["SPOTIFY_CLIENT_SECRET"]
  end

  def fetch(title, artist)
    token = access_token
    return nil unless token

    track = search_track(token, title, artist)
    return nil unless track

    features = audio_features(token, track["id"])

    key_name = features ? PITCH_CLASSES[features["key"]] : nil
    key_mode = features ? (features["mode"] == 1 ? "major" : "minor") : nil
    bpm      = features ? features["tempo"]&.round(1) : nil

    Result.new(
      track_id:  track["id"],
      track_url: track.dig("external_urls", "spotify"),
      bpm:       bpm,
      key_name:  key_name,
      key_mode:  key_mode
    )
  rescue => e
    Rails.logger.error("Spotify error: #{e.message}")
    nil
  end

  private

  def access_token
    response = HTTParty.post(TOKEN_URL,
      body: { grant_type: "client_credentials" },
      headers: {
        "Authorization" => "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}",
        "Content-Type"  => "application/x-www-form-urlencoded"
      },
      timeout: 5
    )
    response.parsed_response["access_token"] if response.success?
  end

  def search_track(token, title, artist)
    query = "#{title} #{artist}".strip
    response = HTTParty.get(SEARCH_URL,
      query: { q: query, type: "track", limit: 1 },
      headers: { "Authorization" => "Bearer #{token}" },
      timeout: 5
    )
    return nil unless response.success?
    response.parsed_response.dig("tracks", "items", 0)
  end

  def audio_features(token, track_id)
    response = HTTParty.get("#{FEATURES_URL}/#{track_id}",
      headers: { "Authorization" => "Bearer #{token}" },
      timeout: 5
    )
    response.success? ? response.parsed_response : nil
  end
end
