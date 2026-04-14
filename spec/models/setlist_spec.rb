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
end
