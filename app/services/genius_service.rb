require "cgi"
require "nokogiri"

class GeniusService
  SEARCH_URL = "https://api.genius.com/search"

  def self.fetch_lyrics(title, artist)
    token = ENV["GENIUS_ACCESS_TOKEN"]
    return nil unless token.present?

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
  rescue => e
    Rails.logger.error("Genius error: #{e.message}")
    nil
  end

  private_class_method def self.scrape_lyrics(url)
    response = HTTParty.get(url, headers: {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    }, timeout: 10)
    return nil unless response.success?

    doc = Nokogiri::HTML(response.body)

    # Genius wraps all lyric sections in divs with data-lyrics-container="true".
    # Using Nokogiri avoids the regex short-circuit bug where (.*?)<\/div> stops
    # at the first nested closing tag, cutting off the content.
    containers = doc.css('[data-lyrics-container="true"]')
    return nil if containers.empty?

    containers.map { |node|
      # Replace <br> with newlines before stripping all other tags
      node.search("br").each { |br| br.replace("\n") }

      # CGI.unescapeHTML handles all HTML entities: named (&amp; &apos;),
      # decimal (&#39;) and hex (&#x27;) — fixing the &#x27; → ' bug.
      CGI.unescapeHTML(node.text).strip
    }.reject(&:empty?).join("\n\n")
  end
end
