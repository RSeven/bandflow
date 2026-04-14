require "rails_helper"

RSpec.describe ChordsScraperService do
  # ——— Helpers ——————————————————————————————————————————————————————————————

  # Builds an HTML page with a .js-store div containing the given data hash
  # encoded exactly as Ultimate Guitar server-renders it.
  def ug_page(data)
    encoded = CGI.escapeHTML(JSON.generate(data))
    "<html><body><div class=\"js-store\" data-content=\"#{encoded}\"></div></body></html>"
  end

  def http_ok(body)
    instance_double(HTTParty::Response, success?: true, body: body)
  end

  def http_error
    instance_double(HTTParty::Response, success?: false, body: "")
  end

  let(:search_results_data) do
    {
      "store" => {
        "page" => {
          "data" => {
            "results" => [
              {
                "type"    => "Chords",
                "tab_url" => "https://tabs.ultimate-guitar.com/tab/queen/bohemian-rhapsody-chords-123",
                "rating"  => 4.9,
                "votes"   => 500
              },
              {
                "type"    => "Tab",
                "tab_url" => "https://tabs.ultimate-guitar.com/tab/queen/bohemian-rhapsody-tabs-456",
                "rating"  => 4.5,
                "votes"   => 100
              }
            ]
          }
        }
      }
    }
  end

  let(:tab_content_data) do
    {
      "store" => {
        "page" => {
          "data" => {
            "tab_view" => {
              "wiki_tab" => {
                "content" => "[ch]Am[/ch]    [ch]G[/ch]    [ch]C[/ch]    [ch]F[/ch]\r\nIs this the real life?"
              }
            }
          }
        }
      }
    }
  end

  # ——— Tests ————————————————————————————————————————————————————————————————

  describe ".fetch" do
    context "when UG returns search results and a tab page" do
      let(:tab_url) { "https://tabs.ultimate-guitar.com/tab/queen/bohemian-rhapsody-chords-123" }

      before do
        allow(HTTParty).to receive(:get)
          .with(ChordsScraperService::UG_SEARCH, anything)
          .and_return(http_ok(ug_page(search_results_data)))

        allow(HTTParty).to receive(:get)
          .with(tab_url, anything)
          .and_return(http_ok(ug_page(tab_content_data)))
      end

      it "returns cleaned chord content" do
        result = described_class.fetch("Bohemian Rhapsody", "Queen")
        expect(result).to be_present
      end

      it "strips [ch]…[/ch] chord annotation tags, leaving bare chord names" do
        result = described_class.fetch("Bohemian Rhapsody", "Queen")
        expect(result).to include("Am")
        expect(result).to include("G")
        expect(result).not_to include("[ch]")
        expect(result).not_to include("[/ch]")
      end

      it "picks the Chords-type result over Tab-type results" do
        # Confirm we never fetch the Tab URL
        expect(HTTParty).not_to receive(:get)
          .with("https://tabs.ultimate-guitar.com/tab/queen/bohemian-rhapsody-tabs-456", anything)

        described_class.fetch("Bohemian Rhapsody", "Queen")
      end

      it "prefers the highest-rated chord tab when multiple exist" do
        high_rated_url = "https://tabs.ultimate-guitar.com/tab/queen/bohemian-rhapsody-chords-999"
        data = search_results_data.deep_dup
        data["store"]["page"]["data"]["results"] << {
          "type"    => "Chords",
          "tab_url" => high_rated_url,
          "rating"  => 5.0,
          "votes"   => 1000
        }
        allow(HTTParty).to receive(:get)
          .with(ChordsScraperService::UG_SEARCH, anything)
          .and_return(http_ok(ug_page(data)))
        allow(HTTParty).to receive(:get)
          .with(high_rated_url, anything)
          .and_return(http_ok(ug_page(tab_content_data)))

        described_class.fetch("Bohemian Rhapsody", "Queen")
        expect(HTTParty).to have_received(:get).with(high_rated_url, anything)
      end
    end

    context "when the search page has no Chords results" do
      before do
        data = search_results_data.deep_dup
        data["store"]["page"]["data"]["results"].reject! { |r| r["type"] == "Chords" }
        allow(HTTParty).to receive(:get)
          .with(ChordsScraperService::UG_SEARCH, anything)
          .and_return(http_ok(ug_page(data)))
      end

      it "returns nil" do
        expect(described_class.fetch("X", "Y")).to be_nil
      end
    end

    context "when the search HTTP request fails" do
      before do
        allow(HTTParty).to receive(:get)
          .with(ChordsScraperService::UG_SEARCH, anything)
          .and_return(http_error)
      end

      it "returns nil" do
        expect(described_class.fetch("X", "Y")).to be_nil
      end
    end

    context "when the tab page has no .js-store div" do
      let(:tab_url) { "https://tabs.ultimate-guitar.com/tab/queen/bohemian-rhapsody-chords-123" }

      before do
        allow(HTTParty).to receive(:get)
          .with(ChordsScraperService::UG_SEARCH, anything)
          .and_return(http_ok(ug_page(search_results_data)))

        allow(HTTParty).to receive(:get)
          .with(tab_url, anything)
          .and_return(http_ok("<html><body>No store here</body></html>"))
      end

      it "returns nil without raising" do
        expect(described_class.fetch("X", "Y")).to be_nil
      end
    end

    context "when a network error occurs" do
      before { allow(HTTParty).to receive(:get).and_raise(Net::OpenTimeout) }

      it "returns nil without raising" do
        expect(described_class.fetch("X", "Y")).to be_nil
      end
    end

    context "when the js-store JSON is malformed" do
      before do
        bad_html = "<html><body><div class=\"js-store\" data-content=\"not valid json\"></div></body></html>"
        allow(HTTParty).to receive(:get)
          .with(ChordsScraperService::UG_SEARCH, anything)
          .and_return(http_ok(bad_html))
      end

      it "returns nil without raising" do
        expect(described_class.fetch("X", "Y")).to be_nil
      end
    end
  end

  describe "chord content cleaning (.clean)" do
    it "strips [tab] and [/tab] wrapper tags" do
      data = tab_content_data.deep_dup
      data["store"]["page"]["data"]["tab_view"]["wiki_tab"]["content"] = "[tab]Am G C F[/tab]"
      allow(HTTParty).to receive(:get)
        .with(ChordsScraperService::UG_SEARCH, anything)
        .and_return(http_ok(ug_page(search_results_data)))
      tab_url = search_results_data.dig("store", "page", "data", "results", 0, "tab_url")
      allow(HTTParty).to receive(:get).with(tab_url, anything)
                                      .and_return(http_ok(ug_page(data)))

      result = described_class.fetch("X", "Y")
      expect(result).to include("Am G C F")
      expect(result).not_to include("[tab]")
    end

    it "normalises Windows-style line endings to Unix" do
      data = tab_content_data.deep_dup
      data["store"]["page"]["data"]["tab_view"]["wiki_tab"]["content"] = "Am\r\nG\r\nC"
      allow(HTTParty).to receive(:get)
        .with(ChordsScraperService::UG_SEARCH, anything)
        .and_return(http_ok(ug_page(search_results_data)))
      tab_url = search_results_data.dig("store", "page", "data", "results", 0, "tab_url")
      allow(HTTParty).to receive(:get).with(tab_url, anything)
                                      .and_return(http_ok(ug_page(data)))

      result = described_class.fetch("X", "Y")
      expect(result).not_to include("\r\n")
    end
  end
end
