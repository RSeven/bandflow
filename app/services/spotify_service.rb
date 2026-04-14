require "nokogiri"

class SpotifyService
  TOKEN_URL  = "https://accounts.spotify.com/api/token"
  SEARCH_URL = "https://api.spotify.com/v1/search"
  FEATURES_URL = "https://api.spotify.com/v1/audio-features"
  SONG_BPM_URL = "https://songbpm.com"

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

    features = songbpm_features(track, title, artist) || audio_features(token, track["id"])

    key_name = extract_key_name(features)
    key_mode = extract_key_mode(features)
    bpm      = extract_bpm(features)

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

  def songbpm_features(track, title, artist)
    response = HTTParty.post("#{SONG_BPM_URL}/searches",
      body: { query: "#{title} #{artist}".strip },
      headers: browser_headers.merge(
        "Origin" => SONG_BPM_URL,
        "Referer" => "#{SONG_BPM_URL}/"
      ),
      follow_redirects: true,
      timeout: 10
    )
    return nil unless response.success?

    detail_path = find_songbpm_detail_path(response.body, track["id"])
    return nil unless detail_path

    detail_response = HTTParty.get("#{SONG_BPM_URL}#{detail_path}",
      headers: browser_headers,
      timeout: 10
    )
    return nil unless detail_response.success?

    parse_songbpm_detail(detail_response.body)
  end

  def find_songbpm_detail_path(html, spotify_track_id)
    doc = Nokogiri::HTML(html)

    doc.css("div.bg-card").each do |card|
      detail_link = card.at_css("a[href^='/@']")
      spotify_link = card.css("a[href*='open.spotify.com/track/']").find do |link|
        link["href"].to_s.include?(spotify_track_id)
      end

      return detail_link["href"] if detail_link && spotify_link
    end

    nil
  end

  def parse_songbpm_detail(html)
    doc = Nokogiri::HTML(html)
    metrics = doc.css("dt").each_with_object({}) do |label_node, values|
      label = label_node.text.strip
      value = label_node.xpath("following-sibling::dd[1]").text.strip
      values[label] = value if value.present?
    end

    mode = doc.text.match(/\bkey and a\s+(major|minor)\s+mode\b/i)&.captures&.first
    key_name = normalize_songbpm_key(metrics["Key"])
    bpm = metrics["Tempo (BPM)"]&.to_f
    return nil unless key_name || bpm || mode

    {
      "key_name" => key_name,
      "key_mode" => mode&.downcase,
      "tempo" => bpm
    }
  end

  def normalize_songbpm_key(value)
    return nil if value.blank?

    key = value.to_s.strip
    key = key.split("/").first
    key = key.tr("♯♭", "#b")

    enharmonic_map = {
      "Bb" => "A#",
      "Db" => "C#",
      "Eb" => "D#",
      "Gb" => "F#",
      "Ab" => "G#"
    }.freeze

    enharmonic_map.fetch(key, key)
  end

  def extract_key_name(features)
    return unless features

    if features.key?("key_name")
      features["key_name"]
    else
      PITCH_CLASSES[features["key"]]
    end
  end

  def extract_key_mode(features)
    return unless features

    if features.key?("key_mode")
      features["key_mode"]
    else
      features["mode"] == 1 ? "major" : "minor"
    end
  end

  def extract_bpm(features)
    return unless features

    value = features["tempo"]
    value&.round(1)
  end

  def browser_headers
    {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    }
  end
end
