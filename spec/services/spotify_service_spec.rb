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

    let(:songbpm_search_response) do
      instance_double(HTTParty::Response,
        success?: true,
        body: <<~HTML
          <html>
            <body>
              <div class="bg-card">
                <a href="/@queen/bohemian-rhapsody">Bohemian Rhapsody</a>
                <div>
                  <a href="https://open.spotify.com/track/abc123">Spotify</a>
                </div>
              </div>
            </body>
          </html>
        HTML
      )
    end

    let(:songbpm_detail_response) do
      instance_double(HTTParty::Response,
        success?: true,
        body: <<~HTML
          <html>
            <body>
              <dl>
                <dt>Key</dt><dd>G</dd>
                <dt>Tempo (BPM)</dt><dd>120</dd>
              </dl>
              <p>The track runs 4 minutes long with a G key and a major mode.</p>
            </body>
          </html>
        HTML
      )
    end

    let(:legacy_features_response) do
      instance_double(HTTParty::Response,
        success?: true,
        parsed_response: {
          "tempo" => 120.0,
          "key" => 7,
          "mode" => 1
        }
      )
    end

    before do
      allow(HTTParty).to receive(:post).and_return(token_response)
      allow(HTTParty).to receive(:get)
        .with(SpotifyService::SEARCH_URL, anything)
        .and_return(search_response)
      allow(HTTParty).to receive(:get)
        .with("#{SpotifyService::SONG_BPM_URL}/@queen/bohemian-rhapsody", anything)
        .and_return(songbpm_detail_response)
      allow(HTTParty).to receive(:post)
        .with("#{SpotifyService::SONG_BPM_URL}/searches", anything)
        .and_return(songbpm_search_response)
      allow(HTTParty).to receive(:get)
        .with("#{SpotifyService::FEATURES_URL}/abc123", anything)
        .and_return(legacy_features_response)

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

    it "matches the SongBPM result using the Spotify track id" do
      service.fetch("Bohemian Rhapsody", "Queen")

      expect(HTTParty).to have_received(:post)
        .with("#{SpotifyService::SONG_BPM_URL}/searches", hash_including(
          body: { query: "Bohemian Rhapsody Queen" }
        ))
      expect(HTTParty).to have_received(:get)
        .with("#{SpotifyService::SONG_BPM_URL}/@queen/bohemian-rhapsody", anything)
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

    it "falls back to legacy audio features when SongBPM has no matching result" do
      allow(HTTParty).to receive(:post)
        .with("#{SpotifyService::SONG_BPM_URL}/searches", anything)
        .and_return(
          instance_double(HTTParty::Response, success?: true, body: "<html><body>No match</body></html>")
        )

      result = service.fetch("Bohemian Rhapsody", "Queen")

      expect(result.bpm).to eq(120.0)
      expect(result.key_name).to eq("G")
      expect(result.key_mode).to eq("major")
    end

    it "normalizes enharmonic keys returned by SongBPM" do
      allow(HTTParty).to receive(:get)
        .with("#{SpotifyService::SONG_BPM_URL}/@queen/bohemian-rhapsody", anything)
        .and_return(
          instance_double(HTTParty::Response,
            success?: true,
            body: <<~HTML
              <html>
                <body>
                  <dl>
                    <dt>Key</dt><dd>G♯/A♭</dd>
                    <dt>Tempo (BPM)</dt><dd>123</dd>
                  </dl>
                  <p>The track runs 4 minutes long with a G♯/A♭ key and a minor mode.</p>
                </body>
              </html>
            HTML
          )
        )

      result = service.fetch("Bohemian Rhapsody", "Queen")

      expect(result.key_name).to eq("G#")
      expect(result.key_mode).to eq("minor")
      expect(result.bpm).to eq(123.0)
    end
  end
end
