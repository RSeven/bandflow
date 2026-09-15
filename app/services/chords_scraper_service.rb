require "nokogiri"

class ChordsScraperService
  CIFRA_URL = "https://www.cifraclub.com.br".freeze

  HEADERS = {
    "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language" => "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7"
  }.freeze

  # Cifra Club rebuilt its song page in 2026: the chart now lives in a <pre>
  # tagged with data-chord-content (CSS classes are hashed and unstable).
  # Older selectors are kept as fallbacks in case the markup rolls back.
  CHART_SELECTORS = [
    "pre[data-chord-content]",
    "#song-sheet-root pre",
    ".cifra_cnt pre"
  ].freeze

  def self.fetch(title, artist)
    artist_slug_candidates(artist).each do |artist_slug|
      slug_candidates(title).each do |title_slug|
        url = "#{CIFRA_URL}/#{artist_slug}/#{title_slug}/"
        response = HTTParty.get(url, headers: HEADERS, timeout: 10)
        next unless response.success?

        chords = extract_chart(response.body)
        return chords if chords.present?
      end
    end

    nil
  rescue => e
    Rails.logger.error("ChordsScraperService error: #{e.message}")
    nil
  end

  private_class_method def self.extract_chart(html)
    doc = Nokogiri::HTML(html)
    pre = CHART_SELECTORS.lazy.map { |selector| doc.at_css(selector) }.find(&:itself)
    return nil unless pre

    content = pre.text.to_s
    content = content.gsub(/\r\n?/, "\n").strip
    content.presence
  end

  # Cifra Club spells "&" as "e" in artist slugs regardless of language
  # ("chitaozinho-e-xororo", "simon-e-garfunkel").
  private_class_method def self.artist_slug_candidates(artist)
    [ artist.to_s.gsub("&", " e "), artist.to_s ]
      .map { |value| slugify(value) }
      .reject(&:blank?)
      .uniq
  end

  private_class_method def self.slug_candidates(title)
    candidates = [ title.to_s ]

    without_parentheticals = title.to_s.gsub(/\s*\([^)]*\)/, " ").squish
    candidates << without_parentheticals if without_parentheticals.present?

    without_version_suffix = without_parentheticals.sub(/\s*-\s*(?:remaster(?:ed)?|version|live|mono|stereo|acoustic)\b.*$/i, "").squish
    candidates << without_version_suffix if without_version_suffix.present?

    candidates
      .map { |value| slugify(value) }
      .reject(&:blank?)
      .uniq
  end

  private_class_method def self.slugify(text)
    I18n.transliterate(text.to_s)
      .downcase
      .gsub(/['’]/, "")
      .gsub(/[^a-z0-9]+/, "-")
      .gsub(/\A-+|-+\z/, "")
  end
end
