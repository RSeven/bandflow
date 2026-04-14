require "rails_helper"

RSpec.describe "Invitations", type: :request do
  let(:admin)      { create(:user) }
  let(:band)       { b = create(:band); create(:band_membership, :admin, user: admin, band: b); b }
  let(:new_user)   { create(:user) }

  describe "POST /bands/:band_id/invitations" do
    before { sign_in(admin) }

    it "creates an invitation and redirects to the link page" do
      expect {
        post band_invitations_path(band)
      }.to change(Invitation, :count).by(1)

      expect(response).to redirect_to(
        link_band_invitation_path(band, Invitation.last)
      )
    end
  end

  describe "GET /invitations/:token (show)" do
    let(:invitation) { create(:invitation, band: band, invited_by: admin) }

    context "when logged in" do
      before { sign_in(new_user) }

      it "returns 200" do
        get invitation_path(invitation.token)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not logged in" do
      it "redirects to registration with session token stored" do
        get invitation_path(invitation.token)
        expect(response).to redirect_to(new_registration_path)
      end
    end

    context "when invitation is already used" do
      before { invitation.mark_used! }

      it "redirects with an error" do
        sign_in(new_user)
        get invitation_path(invitation.token)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /invitations/:token (accept)" do
    let(:invitation) { create(:invitation, band: band, invited_by: admin) }

    before do
      invitation # force eager evaluation before sign_in so the band membership isn't created inside the change block
      sign_in(new_user)
    end

    it "adds user to band and marks invitation used" do
      expect {
        post accept_invitation_path(invitation.token)
      }.to change(BandMembership, :count).by(1)

      expect(invitation.reload.used?).to be true
      expect(response).to redirect_to(band_path(band))
    end

    it "does not add user twice if already a member" do
      create(:band_membership, user: new_user, band: band)
      expect {
        post accept_invitation_path(invitation.token)
      }.not_to change(BandMembership, :count)
    end

    it "rejects a used invitation" do
      invitation.mark_used!
      post accept_invitation_path(invitation.token)
      expect(response).to redirect_to(root_path)
    end
  end
end
