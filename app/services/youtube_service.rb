class YoutubeService
  SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"

  def self.fetch_url(title, artist)
    api_key = ENV["YOUTUBE_API_KEY"]
    return nil unless api_key.present?

    query = "#{title} #{artist} official".strip
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
    video_id ? "https://www.youtube.com/watch?v=#{video_id}" : nil
  rescue => e
    Rails.logger.error("YouTube error: #{e.message}")
    nil
  end
end
