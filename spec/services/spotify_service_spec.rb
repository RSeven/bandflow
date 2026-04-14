require "rails_helper"

RSpec.describe SpotifyService do
  subject(:service) { described_class.new }

  describe "#fetch" do
    let(:token_response) do
      instance_double(HTTParty::Response,
        success?: true,
        parsed_response: { "access_token" => "test_token" }
      )
    end

    let(:search_response) do
      instance_double(HTTParty::Response,
        success?: true,
        parsed_response: {
          "tracks" => {
            "items" => [ {
              "id" => "abc123",
              "external_urls" => { "spotify" => "https://open.spotify.com/track/abc123" }
            } ]
          }
        }
      )
    end

    let(:features_response) do
      instance_double(HTTParty::Response,
        success?: true,
        parsed_response: {
          "tempo" => 120.0,
          "key"   => 7,    # G
          "mode"  => 1     # major
        }
      )
    end

    before do
      allow(HTTParty).to receive(:post).and_return(token_response)
      allow(HTTParty).to receive(:get)
        .with(SpotifyService::SEARCH_URL, anything)
        .and_return(search_response)
      allow(HTTParty).to receive(:get)
        .with("#{SpotifyService::FEATURES_URL}/abc123", anything)
        .and_return(features_response)

      ENV["SPOTIFY_CLIENT_ID"]     = "fake_id"
      ENV["SPOTIFY_CLIENT_SECRET"] = "fake_secret"
    end

    it "returns a Result with correct data" do
      result = service.fetch("Bohemian Rhapsody", "Queen")

      expect(result).not_to be_nil
      expect(result.track_id).to eq("abc123")
      expect(result.track_url).to eq("https://open.spotify.com/track/abc123")
      expect(result.bpm).to eq(120.0)
      expect(result.key_name).to eq("G")
      expect(result.key_mode).to eq("major")
    end

    it "returns nil gracefully when access token fetch fails" do
      allow(HTTParty).to receive(:post).and_return(
        instance_double(HTTParty::Response, success?: false, parsed_response: {})
      )
      expect(service.fetch("X", "Y")).to be_nil
    end

    it "returns nil when no tracks found" do
      allow(HTTParty).to receive(:get)
        .with(SpotifyService::SEARCH_URL, anything)
        .and_return(
          instance_double(HTTParty::Response,
            success?: true,
            parsed_response: { "tracks" => { "items" => [] } }
          )
        )
      expect(service.fetch("Unknown Song", "Nobody")).to be_nil
    end
  end
end
