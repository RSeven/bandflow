require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it { is_expected.to be_valid }

  describe "validations" do
    it "requires a name" do
      user.name = ""
      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it "requires an email address" do
      user.email_address = ""
      expect(user).not_to be_valid
    end

    it "rejects duplicate emails (case-insensitive)" do
      create(:user, email_address: "test@example.com")
      user.email_address = "TEST@example.com"
      expect(user).not_to be_valid
    end

    it "rejects malformed email addresses" do
      user.email_address = "not-an-email"
      expect(user).not_to be_valid
    end
  end

  describe "#member_of?" do
    let(:band) { create(:band) }

    it "returns true when user belongs to band" do
      user.save!
      create(:band_membership, user: user, band: band)
      expect(user.member_of?(band)).to be true
    end

    it "returns false when user does not belong to band" do
      user.save!
      expect(user.member_of?(band)).to be false
    end
  end

  describe "#admin_of?" do
    let(:band) { create(:band) }

    it "returns true for admin members" do
      user.save!
      create(:band_membership, :admin, user: user, band: band)
      expect(user.admin_of?(band)).to be true
    end

    it "returns false for regular members" do
      user.save!
      create(:band_membership, user: user, band: band, role: "member")
      expect(user.admin_of?(band)).to be false
    end
  end
end
