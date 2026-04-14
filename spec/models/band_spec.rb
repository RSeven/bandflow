require "rails_helper"

RSpec.describe Band, type: :model do
  subject(:band) { build(:band) }

  it { is_expected.to be_valid }

  describe "slug generation" do
    it "auto-generates a slug from the name on create" do
      band = create(:band, name: "The Rolling Stones")
      expect(band.slug).to eq("the-rolling-stones")
    end

    it "generates a unique slug when one already exists" do
      create(:band, name: "The Beatles")
      band2 = create(:band, name: "The Beatles")
      expect(band2.slug).to eq("the-beatles-1")
    end

    it "strips special characters from the slug" do
      band = create(:band, name: "AC/DC & Friends!")
      expect(band.slug).to match(/\A[a-z0-9\-]+\z/)
    end
  end

  describe "validations" do
    it "requires a name" do
      band.name = ""
      expect(band).not_to be_valid
    end
  end

  describe "associations" do
    it "destroys memberships when band is deleted" do
      band.save!
      user = create(:user)
      create(:band_membership, user: user, band: band)
      expect { band.destroy }.to change(BandMembership, :count).by(-1)
    end

    it "destroys musics when band is deleted" do
      band.save!
      create(:music, band: band)
      expect { band.destroy }.to change(Music, :count).by(-1)
    end
  end
end
