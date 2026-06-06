require "rails_helper"

RSpec.describe Setlist, type: :model do
  subject(:setlist) { build(:setlist) }

  it { is_expected.to be_valid }

  describe "validations" do
    it "requires a title" do
      setlist.title = ""
      expect(setlist).not_to be_valid
    end
  end

  describe "#music_count" do
    it "counts only music items, not events" do
      setlist.save!
      music = create(:music, band: setlist.band)
      event = create(:event, band: setlist.band)
      setlist.setlist_items.create!(item: music)
      setlist.setlist_items.create!(item: event)
      expect(setlist.music_count).to eq(1)
    end
  end

  describe "#ordered_items" do
    it "returns items in position order" do
      setlist.save!
      music1 = create(:music, band: setlist.band)
      music2 = create(:music, band: setlist.band)
      si1 = setlist.setlist_items.create!(item: music1)
      si2 = setlist.setlist_items.create!(item: music2)
      expect(setlist.ordered_items.map(&:id)).to eq([ si1.id, si2.id ])
    end
  end

  describe "#copy_with_items" do
    it "copies setlist details and ordered item references" do
      original = create(:setlist, title: "Festival", notes: "Keep it tight")
      music = create(:music, band: original.band)
      event = create(:event, band: original.band)
      original.setlist_items.create!(item: music, position: 0)
      original.setlist_items.create!(item: event, position: 1)

      copy = original.copy_with_items(title: "Festival 2")

      expect(copy).to be_persisted
      expect(copy).not_to eq(original)
      expect(copy.attributes.slice("band_id", "title", "performance_date", "notes")).to eq(
        "band_id" => original.band_id,
        "title" => "Festival 2",
        "performance_date" => original.performance_date,
        "notes" => "Keep it tight"
      )
      expect(copy.ordered_items.map { |item| [ item.item_type, item.item_id, item.position ] }).to eq([
        [ "Music", music.id, 0 ],
        [ "Event", event.id, 1 ]
      ])
    end
  end
end
