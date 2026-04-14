require "rails_helper"
require "pdf/inspector"

RSpec.describe SetlistPdfService do
  let(:band)    { create(:band, name: "The Testers") }
  let(:setlist) { create(:setlist, band: band, title: "Friday Night", performance_date: Date.new(2026, 5, 1)) }

  def add_musics(setlist, count)
    count.times do |i|
      music = create(:music, band: setlist.band, title: "Song #{i + 1}", artist: "Artist #{i + 1}")
      setlist.setlist_items.create!(item: music, position: i)
    end
  end

  describe ".render" do
    it "returns a non-empty PDF byte string" do
      add_musics(setlist, 5)
      pdf = described_class.render(setlist)
      expect(pdf).to be_a(String)
      expect(pdf.byteslice(0, 5)).to eq("%PDF-")
    end

    it "renders a single page regardless of item count" do
      add_musics(setlist, 50)
      pdf = described_class.render(setlist)
      reader = PDF::Reader.new(StringIO.new(pdf)) rescue nil
      # Prawn doesn't ship PDF::Reader; fall back to counting `/Type /Page` markers
      page_count = pdf.scan(%r{/Type\s*/Page[^s]}).size
      expect(page_count).to eq(1)
    end

    it "handles an empty setlist without raising" do
      expect { described_class.render(setlist) }.not_to raise_error
    end

    it "renders the setlist title, band name, and every music title" do
      add_musics(setlist, 3)
      pdf  = described_class.render(setlist)
      text = PDF::Inspector::Text.analyze(pdf).strings.join(" ")

      expect(text).to include("Friday Night")
      expect(text).to include("The Testers")
      expect(text).to include("Song 1")
      expect(text).to include("Song 3")
    end
  end
end
