require "rails_helper"

RSpec.describe Invitation, type: :model do
  describe "token generation" do
    it "auto-generates a token on create" do
      invitation = create(:invitation)
      expect(invitation.token).to be_present
      expect(invitation.token.length).to be >= 32
    end

    it "generates unique tokens" do
      inv1 = create(:invitation)
      inv2 = create(:invitation)
      expect(inv1.token).not_to eq(inv2.token)
    end
  end

  describe "#used?" do
    it "returns false when used_at is nil" do
      inv = build(:invitation, used_at: nil)
      expect(inv.used?).to be false
    end

    it "returns true when used_at is set" do
      inv = build(:invitation, used_at: Time.current)
      expect(inv.used?).to be true
    end
  end

  describe "#mark_used!" do
    it "sets used_at to current time" do
      inv = create(:invitation)
      inv.mark_used!
      expect(inv.reload.used_at).to be_present
    end
  end
end
