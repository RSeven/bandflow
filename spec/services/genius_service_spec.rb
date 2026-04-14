require "rails_helper"

RSpec.describe GeniusService do
  # ——— Helpers ——————————————————————————————————————————————————————————————

  def genius_search_response(url:)
    body = JSON.generate({
      "response" => {
        "hits" => [
          { "result" => { "url" => url } }
        ]
      }
    })
    instance_double(HTTParty::Response, success?: true, parsed_response: JSON.parse(body))
  end

  def genius_page_response(html)
    instance_double(HTTParty::Response, success?: true, body: html)
  end

  # Builds a minimal Genius-style HTML page with lyrics containers.
  def genius_html(*lyric_sections)
    sections_html = lyric_sections.map { |text|
      # Wrap each section in a container with nested divs to test that Nokogiri
      # traversal is not cut off by inner closing tags.
      <<~HTML
        <div data-lyrics-container="true">
          <div class="inner">#{text}</div>
        </div>
      HTML
    }.join
    "<html><body>#{sections_html}</body></html>"
  end

  # ——— Tests ————————————————————————————————————————————————————————————————

  before do
    stub_const("ENV", ENV.to_hash.merge("GENIUS_ACCESS_TOKEN" => "fake_token"))
  end

  describe ".fetch_lyrics" do
    context "when Genius returns lyrics" do
      let(:song_url) { "https://genius.com/queen-bohemian-rhapsody-lyrics" }

      before do
        allow(HTTParty).to receive(:get)
          .with(GeniusService::SEARCH_URL, anything)
          .and_return(genius_search_response(url: song_url))
      end

      it "returns the full lyrics text" do
        html = genius_html("Is this the real life?<br/>Is this just fantasy?")
        allow(HTTParty).to receive(:get).with(song_url, anything)
                                        .and_return(genius_page_response(html))

        result = described_class.fetch_lyrics("Bohemian Rhapsody", "Queen")
        expect(result).to include("Is this the real life?")
        expect(result).to include("Is this just fantasy?")
      end

      it "joins multiple lyric containers with a blank line" do
        html = genius_html("Verse 1 text", "Chorus text")
        allow(HTTParty).to receive(:get).with(song_url, anything)
                                        .and_return(genius_page_response(html))

        result = described_class.fetch_lyrics("Bohemian Rhapsody", "Queen")
        expect(result).to include("Verse 1 text")
        expect(result).to include("Chorus text")
        expect(result).to match(/Verse 1 text\n\nChorus text/)
      end

      it "converts <br> tags to newlines" do
        html = genius_html("Line one<br>Line two<br/>Line three")
        allow(HTTParty).to receive(:get).with(song_url, anything)
                                        .and_return(genius_page_response(html))

        result = described_class.fetch_lyrics("X", "Y")
        expect(result).to eq("Line one\nLine two\nLine three")
      end

      # This was the reported bug: &#x27; was not being decoded
      it "decodes hex HTML entities (&#x27; → apostrophe)" do
        html = genius_html("I&#x27;m on a highway to hell")
        allow(HTTParty).to receive(:get).with(song_url, anything)
                                        .and_return(genius_page_response(html))

        result = described_class.fetch_lyrics("X", "Y")
        expect(result).to eq("I'm on a highway to hell")
        expect(result).not_to include("&#x27;")
      end

      it "decodes decimal HTML entities (&#39; → apostrophe)" do
        html = genius_html("Don&#39;t stop me now")
        allow(HTTParty).to receive(:get).with(song_url, anything)
                                        .and_return(genius_page_response(html))

        result = described_class.fetch_lyrics("X", "Y")
        expect(result).to eq("Don't stop me now")
      end

      it "decodes named HTML entities (&amp; → &)" do
        html = genius_html("Rock &amp; Roll")
        allow(HTTParty).to receive(:get).with(song_url, anything)
                                        .and_return(genius_page_response(html))

        result = described_class.fetch_lyrics("X", "Y")
        expect(result).to eq("Rock & Roll")
      end

      # Regression: old regex cut off at the first inner </div>,
      # producing incomplete lyrics for songs with nested HTML structure.
      it "does not truncate lyrics at inner closing tags" do
        deeply_nested = <<~HTML
          <div data-lyrics-container="true">
            <div><div><span>First line</span></div></div>
            <br>
            <div><span>Second line</span></div>
          </div>
        HTML
        html = "<html><body>#{deeply_nested}</body></html>"
        allow(HTTParty).to receive(:get).with(song_url, anything)
                                        .and_return(genius_page_response(html))

        result = described_class.fetch_lyrics("X", "Y")
        expect(result).to include("First line")
        expect(result).to include("Second line")
      end

      it "returns nil when the page has no lyric containers" do
        html = "<html><body><p>No lyrics here</p></body></html>"
        allow(HTTParty).to receive(:get).with(song_url, anything)
                                        .and_return(genius_page_response(html))

        expect(described_class.fetch_lyrics("X", "Y")).to be_nil
      end
    end

    context "when Genius search returns no hits" do
      before do
        body = JSON.generate({ "response" => { "hits" => [] } })
        allow(HTTParty).to receive(:get).with(GeniusService::SEARCH_URL, anything)
          .and_return(
            instance_double(HTTParty::Response,
              success?: true,
              parsed_response: JSON.parse(body))
          )
      end

      it "returns nil" do
        expect(described_class.fetch_lyrics("Unknown Song", "Nobody")).to be_nil
      end
    end

    context "when the Genius API token is missing" do
      before { stub_const("ENV", ENV.to_hash.merge("GENIUS_ACCESS_TOKEN" => nil)) }

      it "returns nil without making any HTTP requests" do
        expect(HTTParty).not_to receive(:get)
        expect(described_class.fetch_lyrics("X", "Y")).to be_nil
      end
    end

    context "when a network error occurs" do
      before do
        allow(HTTParty).to receive(:get).and_raise(Net::OpenTimeout)
      end

      it "returns nil without raising" do
        expect(described_class.fetch_lyrics("X", "Y")).to be_nil
      end
    end
  end
end
