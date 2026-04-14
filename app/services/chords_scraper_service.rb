require "cgi"
require "nokogiri"

# Scrapes chord tabs from Ultimate Guitar.
# UG embeds all page data as HTML-encoded JSON in a <div class="js-store">
# element, which is server-side rendered — no JavaScript execution needed.
class ChordsScraperService
  UG_SEARCH = "https://www.ultimate-guitar.com/search.php"

  HEADERS = {
    "User-Agent"      => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Accept"          => "text/html,application/xhtml+xml",
    "Accept-Language" => "en-US,en;q=0.9"
  }.freeze

  def self.fetch(title, artist)
    tab_url = find_tab_url(title, artist)
    return nil unless tab_url

    fetch_tab_content(tab_url)
  rescue => e
    Rails.logger.error("ChordsScraperService error: #{e.message}")
    nil
  end

  private_class_method def self.find_tab_url(title, artist)
    query    = "#{title} #{artist}"
    response = HTTParty.get(UG_SEARCH,
      query:   { search_type: "title", value: query },
      headers: HEADERS,
      timeout: 10
    )
    return nil unless response.success?

    data = extract_js_store(response.body)
    return nil unless data

    results = data.dig("store", "page", "data", "results") || []

    # Prefer official / high-rated chord tabs; fall back to first chords result
    chord_tabs = results.select { |r| r["type"] == "Chords" }
    return nil if chord_tabs.empty?

    best = chord_tabs.max_by { |r| r["rating"].to_f * r["votes"].to_i }
    best&.dig("tab_url")
  end

  private_class_method def self.fetch_tab_content(tab_url)
    response = HTTParty.get(tab_url, headers: HEADERS, timeout: 10)
    return nil unless response.success?

    data = extract_js_store(response.body)
    return nil unless data

    raw = data.dig("store", "page", "data", "tab_view", "wiki_tab", "content")
    return nil unless raw.present?

    clean(raw)
  end

  # Extracts the HTML-encoded JSON blob from UG's server-rendered .js-store div.
  private_class_method def self.extract_js_store(html)
    doc   = Nokogiri::HTML(html)
    store = doc.at_css(".js-store")
    return nil unless store

    raw = store["data-content"]
    return nil unless raw.present?

    JSON.parse(CGI.unescapeHTML(raw))
  rescue JSON::ParseError
    nil
  end

  # UG uses [ch]Chord[/ch] for inline chord annotations and [tab]…[/tab]
  # wrappers. Strip markup tags and normalise whitespace.
  private_class_method def self.clean(content)
    content
      .gsub(/\[tab\]|\[\/tab\]/i,        "")
      .gsub(/\[ch\](.*?)\[\/ch\]/i,      '\1')
      .gsub(/\[verse.*?\]|\[chorus.*?\]|\[bridge.*?\]/i) { |m|
        "\n[#{m.match(/\w+/)[0].capitalize}]\n"
      }
      .gsub(/\r\n/, "\n")
      .gsub(/\n{3,}/, "\n\n")
      .strip
  end
end
