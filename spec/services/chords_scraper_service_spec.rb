require "rails_helper"

RSpec.describe ChordsScraperService do
  def http_ok(body)
    instance_double(HTTParty::Response, success?: true, body: body)
  end

  def http_error
    instance_double(HTTParty::Response, success?: false, body: "")
  end

  def http_forbidden
    instance_double(HTTParty::Response, success?: false, body: "<h1>Access Denied</h1>")
  end

  # Mirrors the current Cifra Club markup: a <pre data-chord-content> whose
  # chords are wrapped in <b data-chord-name> tags.
  def cifra_page(content)
    marked = content.gsub(/\b([A-G][#b]?(?:m|maj|dim|aug|sus)?\d*)\b(?=\s|$)/) { "<b data-chord-name=\"#{$1}\">#{$1}</b>" }
    <<~HTML
      <html>
        <body>
          <div id="song-sheet-root">
            <pre class="_crVx" data-chord-content="true" data-chord-select="true">#{marked}</pre>
          </div>
        </body>
      </html>
    HTML
  end

  def legacy_cifra_page(content)
    <<~HTML
      <html>
        <body>
          <div class="cifra_cnt">
            <pre>#{content}</pre>
          </div>
        </body>
      </html>
    HTML
  end

  describe ".fetch" do
    context "when Cifra Club has a matching chart page" do
      before do
        allow(HTTParty).to receive(:get)
          .with("https://www.cifraclub.com.br/queen/bohemian-rhapsody/", anything)
          .and_return(http_ok(cifra_page("[Intro]\nF#m7  B7\nIs this the real life?")))
      end

      it "returns cleaned chord content" do
        result = described_class.fetch("Bohemian Rhapsody", "Queen")
        expect(result).to be_present
        expect(result).to include("[Intro]")
        expect(result).to include("F#m7  B7")
      end

      it "uses artist and title slugs to build the Cifra Club URL" do
        described_class.fetch("Bohemian Rhapsody", "Queen")

        expect(HTTParty).to have_received(:get)
          .with("https://www.cifraclub.com.br/queen/bohemian-rhapsody/", anything)
      end
    end

    context "when Cifra Club serves the legacy markup" do
      before do
        allow(HTTParty).to receive(:get)
          .with("https://www.cifraclub.com.br/queen/bohemian-rhapsody/", anything)
          .and_return(http_ok(legacy_cifra_page("[Intro]\nF#m7  B7")))
      end

      it "still extracts the chart" do
        expect(described_class.fetch("Bohemian Rhapsody", "Queen")).to include("F#m7  B7")
      end
    end

    context "when the title needs version suffix cleanup" do
      before do
        allow(HTTParty).to receive(:get)
          .with("https://www.cifraclub.com.br/queen/bohemian-rhapsody-remastered-2011/", anything)
          .and_return(http_error)
        allow(HTTParty).to receive(:get)
          .with("https://www.cifraclub.com.br/queen/bohemian-rhapsody/", anything)
          .and_return(http_ok(cifra_page("C  G\nMama, just killed a man")))
      end

      it "retries with a simplified title slug" do
        result = described_class.fetch("Bohemian Rhapsody - Remastered 2011", "Queen")

        expect(result).to include("Mama, just killed a man")
      end
    end

    context "when the artist name contains an ampersand" do
      before do
        allow(HTTParty).to receive(:get)
          .with("https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/", anything)
          .and_return(http_ok(cifra_page("[Intro]\nD  A  Bm")))
      end

      it "spells the ampersand as 'e' in the artist slug" do
        result = described_class.fetch("Evidências", "Chitãozinho & Xororó")

        expect(result).to include("D  A  Bm")
        expect(HTTParty).to have_received(:get)
          .with("https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/", anything)
      end
    end

    context "when the fetched page has no chart content" do
      before do
        allow(HTTParty).to receive(:get)
          .with("https://www.cifraclub.com.br/queen/bohemian-rhapsody/", anything)
          .and_return(http_ok("<html><body>No pre here</body></html>"))
      end

      it "returns nil" do
        expect(described_class.fetch("Bohemian Rhapsody", "Queen")).to be_nil
      end
    end

    context "when the Cifra Club request fails" do
      before do
        allow(HTTParty).to receive(:get)
          .with("https://www.cifraclub.com.br/queen/bohemian-rhapsody/", anything)
          .and_return(http_error)
      end

      it "returns nil" do
        expect(described_class.fetch("Bohemian Rhapsody", "Queen")).to be_nil
      end
    end

    context "when Cifra Club denies the request" do
      before do
        allow(HTTParty).to receive(:get)
          .with("https://www.cifraclub.com.br/queen/bohemian-rhapsody/", anything)
          .and_return(http_forbidden)
      end

      it "returns nil" do
        expect(described_class.fetch("Bohemian Rhapsody", "Queen")).to be_nil
      end
    end

    context "when a network error occurs" do
      before { allow(HTTParty).to receive(:get).and_raise(Net::OpenTimeout) }

      it "returns nil without raising" do
        expect(described_class.fetch("X", "Y")).to be_nil
      end
    end
  end
end
