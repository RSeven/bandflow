require "rails_helper"

RSpec.describe ItunesSearchService do
  # Builds a fake HTTParty::Response with a given body string and success flag.
  # iTunes returns Content-Type: text/javascript, so parsed_response is a raw
  # String — this helper replicates that real-world behaviour.
  def itunes_response(body:, success: true)
    instance_double(HTTParty::Response, success?: success, body: body)
  end

  def json_body(results)
    JSON.generate({ "resultCount" => results.size, "results" => results })
  end

  let(:track_fixture) do
    {
      "trackName"     => "Bohemian Rhapsody",
      "artistName"    => "Queen",
      "artworkUrl100" => "https://example.com/art.jpg",
      "previewUrl"    => nil
    }
  end

  describe ".search" do
    context "when the API returns a successful response" do
      before do
        allow(HTTParty).to receive(:get)
          .and_return(itunes_response(body: json_body([ track_fixture ])))
      end

      it "returns an array of Result structs" do
        results = described_class.search("Bohemian")
        expect(results.size).to eq(1)
        expect(results.first).to be_a(ItunesSearchService::Result)
      end

      it "maps track fields correctly" do
        result = described_class.search("Bohemian").first
        expect(result.track_name).to  eq("Bohemian Rhapsody")
        expect(result.artist_name).to eq("Queen")
        expect(result.artwork_url).to eq("https://example.com/art.jpg")
        expect(result.preview_url).to be_nil
      end

      it "respects the limit parameter" do
        tracks = Array.new(3) { track_fixture.merge("trackName" => "Song #{_1}") }
        allow(HTTParty).to receive(:get)
          .and_return(itunes_response(body: json_body(tracks)))

        results = described_class.search("Song", limit: 3)
        expect(results.size).to eq(3)
      end

      it "returns an empty array when the results key is missing" do
        allow(HTTParty).to receive(:get)
          .and_return(itunes_response(body: JSON.generate({ "resultCount" => 0 })))

        expect(described_class.search("nothing")).to eq([])
      end
    end

    # This is the exact bug that was reported: iTunes returns Content-Type:
    # text/javascript, so HTTParty's parsed_response is the raw JSON String
    # rather than a Hash. The service must parse response.body itself.
    context "when the response body is a raw JSON string (text/javascript content-type)" do
      it "does not raise 'undefined method map for String' and returns results" do
        raw_json = json_body([ track_fixture ])
        # Simulate what HTTParty does with text/javascript: parsed_response is a String
        response = instance_double(HTTParty::Response, success?: true, body: raw_json)
        allow(HTTParty).to receive(:get).and_return(response)

        expect { described_class.search("Queen") }.not_to raise_error
        results = described_class.search("Queen")
        expect(results.first.artist_name).to eq("Queen")
      end
    end

    context "when the API returns a non-2xx status" do
      it "returns an empty array" do
        allow(HTTParty).to receive(:get)
          .and_return(itunes_response(body: "", success: false))

        expect(described_class.search("anything")).to eq([])
      end
    end

    context "when the response body is not valid JSON" do
      it "returns an empty array without raising" do
        allow(HTTParty).to receive(:get)
          .and_return(itunes_response(body: "Service Unavailable"))

        expect(described_class.search("anything")).to eq([])
      end
    end

    context "when a network error occurs" do
      it "returns an empty array on timeout" do
        allow(HTTParty).to receive(:get).and_raise(Net::OpenTimeout)
        expect(described_class.search("anything")).to eq([])
      end

      it "returns an empty array on connection refused" do
        allow(HTTParty).to receive(:get).and_raise(Errno::ECONNREFUSED)
        expect(described_class.search("anything")).to eq([])
      end
    end
  end
end
