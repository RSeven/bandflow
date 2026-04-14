class ItunesSearchService
  BASE_URL = "https://itunes.apple.com/search"

  Result = Struct.new(:track_name, :artist_name, :artwork_url, :preview_url, keyword_init: true)

  def self.search(query, limit: 10)
    response = HTTParty.get(BASE_URL, query: {
      term: query,
      entity: "musicTrack",
      limit: limit,
      media: "music"
    }, timeout: 5)

    return [] unless response.success?

    # iTunes returns Content-Type: text/javascript, which HTTParty does not
    # auto-parse as JSON. Always parse from the raw body to be safe.
    data    = JSON.parse(response.body)
    results = data["results"] || []

    results.map do |r|
      Result.new(
        track_name: r["trackName"],
        artist_name: r["artistName"],
        artwork_url: r["artworkUrl100"],
        preview_url: r["previewUrl"]
      )
    end
  rescue => e
    Rails.logger.error("iTunes search error: #{e.message}")
    []
  end
end
