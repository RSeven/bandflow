require "rails_helper"

RSpec.describe YoutubeService do
  describe ".fetch_url" do
    let(:query) { "Bohemian Rhapsody Queen official" }

    before do
      stub_const("ENV", ENV.to_hash.merge("YOUTUBE_API_KEY" => "test_key"))
    end

    it "returns the API result when the YouTube API succeeds" do
      allow(HTTParty).to receive(:get)
        .with(YoutubeService::SEARCH_URL, anything)
        .and_return(
          instance_double(HTTParty::Response,
            success?: true,
            parsed_response: {
              "items" => [
                { "id" => { "videoId" => "abc123def45" } }
              ]
            })
        )

      expect(described_class.fetch_url("Bohemian Rhapsody", "Queen"))
        .to eq("https://www.youtube.com/watch?v=abc123def45")
    end

    it "falls back to scraping YouTube search results when the API request fails" do
      allow(HTTParty).to receive(:get)
        .with(YoutubeService::SEARCH_URL, anything)
        .and_return(instance_double(HTTParty::Response, success?: false, parsed_response: {}))
      allow(HTTParty).to receive(:get)
        .with(YoutubeService::YOUTUBE_SEARCH_URL, anything)
        .and_return(
          instance_double(HTTParty::Response,
            success?: true,
            body: %({"videoId":"zyx987wvu65"}))
        )

      expect(described_class.fetch_url("Bohemian Rhapsody", "Queen"))
        .to eq("https://www.youtube.com/watch?v=zyx987wvu65")
    end

    it "falls back to scraping when no API key is configured" do
      stub_const("ENV", ENV.to_hash.merge("YOUTUBE_API_KEY" => nil))
      allow(HTTParty).to receive(:get)
        .with(YoutubeService::YOUTUBE_SEARCH_URL, anything)
        .and_return(
          instance_double(HTTParty::Response,
            success?: true,
            body: %(<a href="/watch?v=zyx987wvu65">Result</a>))
        )

      expect(described_class.fetch_url("Bohemian Rhapsody", "Queen"))
        .to eq("https://www.youtube.com/watch?v=zyx987wvu65")
    end

    it "returns nil when neither the API nor the search page yields a video" do
      allow(HTTParty).to receive(:get)
        .with(YoutubeService::SEARCH_URL, anything)
        .and_return(instance_double(HTTParty::Response, success?: false, parsed_response: {}))
      allow(HTTParty).to receive(:get)
        .with(YoutubeService::YOUTUBE_SEARCH_URL, anything)
        .and_return(
          instance_double(HTTParty::Response,
            success?: true,
            body: "<html><body>No video ids here</body></html>")
        )

      expect(described_class.fetch_url("Bohemian Rhapsody", "Queen")).to be_nil
    end
  end
end
