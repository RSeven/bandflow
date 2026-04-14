class YoutubeService
  SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"
  YOUTUBE_SEARCH_URL = "https://www.youtube.com/results"
  YOUTUBE_WATCH_URL = "https://www.youtube.com/watch?v="

  def self.fetch_url(title, artist)
    api_key = ENV["YOUTUBE_API_KEY"]
    query = "#{title} #{artist} official".strip

    api_url = fetch_via_api(query, api_key)
    return api_url if api_url.present?

    fetch_via_search(query)
  rescue => e
    Rails.logger.error("YouTube error: #{e.message}")
    nil
  end

  def self.fetch_via_api(query, api_key)
    return nil unless api_key.present?

    response = HTTParty.get(SEARCH_URL,
      query: {
        part: "snippet",
        q: query,
        type: "video",
        maxResults: 1,
        key: api_key
      },
      timeout: 5
    )
    return nil unless response.success?

    video_id = response.parsed_response.dig("items", 0, "id", "videoId")
    video_id.present? ? "#{YOUTUBE_WATCH_URL}#{video_id}" : nil
  end

  def self.fetch_via_search(query)
    response = HTTParty.get(YOUTUBE_SEARCH_URL,
      query: { search_query: query },
      headers: {
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
      },
      timeout: 10
    )
    return nil unless response.success?

    video_id = extract_video_id(response.body)
    video_id.present? ? "#{YOUTUBE_WATCH_URL}#{video_id}" : nil
  end

  def self.extract_video_id(body)
    body[/\"videoId\":\"([A-Za-z0-9_-]{11})\"/, 1] ||
      body[%r{/watch\?v=([A-Za-z0-9_-]{11})}, 1]
  end
end
