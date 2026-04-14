require "nokogiri"

class ChordsScraperService
  CIFRA_URL = "https://www.cifraclub.com"

  HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Accept" => "text/html,application/xhtml+xml",
    "Accept-Language" => "en-US,en;q=0.9"
  }.freeze

  def self.fetch(title, artist)
    slug_candidates(title).each do |title_slug|
      url = "#{CIFRA_URL}/#{slugify(artist)}/#{title_slug}/"
      response = HTTParty.get(url, headers: HEADERS, timeout: 10)
      next unless response.success?

      chords = extract_chart(response.body)
      return chords if chords.present?
    end

    nil
  rescue => e
    Rails.logger.error("ChordsScraperService error: #{e.message}")
    nil
  end

  private_class_method def self.extract_chart(html)
    doc = Nokogiri::HTML(html)
    pre = doc.at_css(".cifra_cnt pre")
    return nil unless pre

    content = pre.text.to_s
    content = content.gsub(/\r\n?/, "\n").strip
    content.presence
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
