require "rails_helper"

RSpec.describe SetlistItem, type: :model do
  describe "auto-positioning" do
    it "assigns incrementing positions" do
      setlist = create(:setlist)
      band    = setlist.band
      music1  = create(:music, band: band)
      music2  = create(:music, band: band)

      si1 = setlist.setlist_items.create!(item: music1)
      si2 = setlist.setlist_items.create!(item: music2)

      expect(si1.position).to eq(0)
      expect(si2.position).to eq(1)
    end

    it "preserves an explicitly provided non-zero position" do
      setlist = create(:setlist)
      music   = create(:music, band: setlist.band)

      si = setlist.setlist_items.create!(item: music, position: 42)

      expect(si.position).to eq(42)
    end

    it "overrides an explicit position of 0 with the next auto position" do
      setlist = create(:setlist)
      band    = setlist.band
      existing = setlist.setlist_items.create!(item: create(:music, band: band))

      si = setlist.setlist_items.create!(item: create(:music, band: band), position: 0)

      expect(existing.position).to eq(0)
      expect(si.position).to eq(1)
    end
  end

  describe "#music_index" do
    it "returns 1-based index among music items only" do
      setlist = create(:setlist)
      band    = setlist.band
      event   = create(:event,  band: band)
      music1  = create(:music,  band: band)
      music2  = create(:music,  band: band)

      setlist.setlist_items.create!(item: event)
      si_m1 = setlist.setlist_items.create!(item: music1)
      si_m2 = setlist.setlist_items.create!(item: music2)

      expect(si_m1.music_index).to eq(1)
      expect(si_m2.music_index).to eq(2)
    end

    it "returns nil for event items" do
      setlist = create(:setlist)
      event   = create(:event, band: setlist.band)
      si      = setlist.setlist_items.create!(item: event)
      expect(si.music_index).to be_nil
    end
  end

  describe "#music? / #event?" do
    let(:setlist) { create(:setlist) }

    it "correctly identifies music items" do
      music = create(:music, band: setlist.band)
      si    = setlist.setlist_items.create!(item: music)
      expect(si.music?).to be true
      expect(si.event?).to be false
    end

    it "correctly identifies event items" do
      event = create(:event, band: setlist.band)
      si    = setlist.setlist_items.create!(item: event)
      expect(si.event?).to be true
      expect(si.music?).to be false
    end
  end
end
