require "cgi"
require "nokogiri"
require "json"

class GeniusService
  SEARCH_URL = "https://api.genius.com/search"
  LRCLIB_SEARCH_URL = "https://lrclib.net/api/search"
  LRCLIB_HEADERS = {
    "User-Agent" => "Bandflow/1.0 (https://bandflow.ruanlps.com)"
  }.freeze

  def self.fetch_lyrics(title, artist)
    token = ENV["GENIUS_ACCESS_TOKEN"]

    if token.present?
      lyrics = fetch_genius_lyrics(title, artist, token)
      return lyrics if lyrics.present?
    end

    fetch_lrclib_lyrics(title, artist)
  rescue => e
    Rails.logger.error("Genius error: #{e.message}")
    nil
  end

  private_class_method def self.fetch_genius_lyrics(title, artist, token)
    query = "#{title} #{artist}".strip
    response = HTTParty.get(SEARCH_URL,
      query: { q: query },
      headers: { "Authorization" => "Bearer #{token}" },
      timeout: 5
    )

    return nil unless response.success?

    hits = response.parsed_response.dig("response", "hits") || []
    hit = hits.first
    return nil unless hit

    song_url = hit.dig("result", "url")
    return nil unless song_url

    scrape_lyrics(song_url)
  end

  private_class_method def self.fetch_lrclib_lyrics(title, artist)
    response = HTTParty.get(LRCLIB_SEARCH_URL,
      query: { track_name: title, artist_name: artist },
      headers: LRCLIB_HEADERS,
      timeout: 10
    )

    return nil unless response.success?

    results = response.parsed_response
    return nil unless results.is_a?(Array)

    result = results
      .select { |item| item["plainLyrics"].present? && !item["instrumental"] }
      .max_by { |item| lrclib_score(item, title, artist) }

    normalize_lrclib_lyrics(result&.dig("plainLyrics")).presence
  end

  private_class_method def self.scrape_lyrics(url)
    response = HTTParty.get(url, headers: {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    }, timeout: 10)
    return nil unless response.success?

    lyrics = extract_lyrics_from_preloaded_state(response.body)
    return lyrics if lyrics.present?

    doc = Nokogiri::HTML(response.body)

    # Fallback for pages where Genius still renders lyric containers directly.
    # Genius wraps all lyric sections in divs with data-lyrics-container="true".
    # Using Nokogiri avoids the regex short-circuit bug where (.*?)<\/div> stops
    # at the first nested closing tag, cutting off the content.
    containers = doc.css('[data-lyrics-container="true"]')
    return nil if containers.empty?

    containers.map { |node|
      normalize_lyrics(extract_text(node))
    }.reject(&:empty?).join("\n\n")
  end

  private_class_method def self.extract_lyrics_from_preloaded_state(html)
    doc = Nokogiri::HTML(html)
    script = doc.css("script").find { |node| node.text.include?("window.__PRELOADED_STATE__ = JSON.parse('") }
    return nil unless script

    match = script.text.match(/window\.__PRELOADED_STATE__ = JSON\.parse\('(?<json>.+?)'\);/m)
    return nil unless match

    decoded = decode_javascript_string(match[:json])
    return nil unless decoded

    state = JSON.parse(decoded)
    lyrics_html = state.dig("songPage", "lyricsData", "body", "html")
    return nil if lyrics_html.blank?

    normalize_lyrics(extract_text(Nokogiri::HTML.fragment(lyrics_html)))
  rescue JSON::ParserError
    nil
  end

  private_class_method def self.lrclib_score(item, title, artist)
    score = 0
    score += 10 if normalized_match?(item["trackName"], title)
    score += 10 if normalized_match?(item["artistName"], artist)
    score += 5 unless item["plainLyrics"].to_s.match?(/\A\s*\[[a-z]+:/i)
    score += 2 if item["syncedLyrics"].blank?
    score
  end

  private_class_method def self.normalized_match?(actual, expected)
    normalize_match_text(actual) == normalize_match_text(expected)
  end

  private_class_method def self.normalize_match_text(value)
    I18n.transliterate(value.to_s)
      .downcase
      .gsub(/[^a-z0-9]+/, " ")
      .squish
  end

  private_class_method def self.decode_javascript_string(value)
    decoded = +""
    index = 0

    while index < value.length
      char = value[index]

      if char == "\\"
        index += 1
        return nil if index >= value.length

        case value[index]
        when "\\", "/", "'"
          decoded << value[index]
        when "b"
          decoded << "\b"
        when "f"
          decoded << "\f"
        when "n"
          decoded << "\n"
        when "r"
          decoded << "\r"
        when "t"
          decoded << "\t"
        when "u"
          hex = value[(index + 1), 4]
          return nil unless hex&.match?(/\A\h{4}\z/)

          decoded << [ hex.to_i(16) ].pack("U")
          index += 4
        else
          decoded << value[index]
        end
      else
        decoded << char
      end

      index += 1
    end

    decoded
  end

  private_class_method def self.extract_text(node)
    node = node.dup
    node.search("br").each { |br| br.replace("\n") }

    # CGI.unescapeHTML handles named, decimal, and hex entities.
    CGI.unescapeHTML(node.text)
  end

  private_class_method def self.normalize_lrclib_lyrics(text)
    return nil if text.blank?

    cleaned = text.to_s
      .gsub(/\r\n?/, "\n")
      .lines
      .reject { |line| line.match?(/\A\s*\[(?:ti|ar|al|by|offset):/i) }
      .join

    normalize_lyrics(cleaned)
  end

  private_class_method def self.normalize_lyrics(text)
    text = text.to_s
    text = text.sub(/\A.*?(?=\[[^\]]+\])/m, "")
    text = text.gsub(/[ \t]+\n/, "\n")
    text = text.gsub(/\n{3,}/, "\n\n")
    text.strip
  end
end
