require "rails_helper"

RSpec.describe "Bands", type: :request do
  let(:user) { create(:user) }
  let(:band) do
    b = create(:band)
    create(:band_membership, :admin, user: user, band: b)
    b
  end

  before { sign_in(user) }

  describe "GET /bands" do
    it "returns 200 and lists user's bands" do
      band # ensure band exists
      get bands_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /bands/:id" do
    it "returns 200 for a member" do
      get band_path(band)
      expect(response).to have_http_status(:ok)
    end

    it "redirects to bands index for non-members" do
      other_band = create(:band)
      get band_path(other_band)
      expect(response).to redirect_to(bands_path)
    end
  end

  describe "POST /bands" do
    it "creates a band and redirects" do
      expect {
        post bands_path, params: { band: { name: "New Band", description: "Desc" } }
      }.to change(Band, :count).by(1)
      expect(response).to redirect_to(band_path(Band.last))
    end

    it "makes the creator an admin" do
      post bands_path, params: { band: { name: "My Band" } }
      membership = BandMembership.find_by(user: user, band: Band.last)
      expect(membership.role).to eq("admin")
    end

    it "renders new with errors on invalid params" do
      post bands_path, params: { band: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /bands/:id" do
    it "updates the band" do
      patch band_path(band), params: { band: { name: "Updated Name" } }
      expect(band.reload.name).to eq("Updated Name")
      expect(response).to redirect_to(band_path(band))
    end
  end

  describe "DELETE /bands/:id" do
    it "destroys the band" do
      band # ensure exists
      expect { delete band_path(band) }.to change(Band, :count).by(-1)
      expect(response).to redirect_to(bands_path)
    end
  end

  describe "unauthenticated access" do
    it "redirects to sign in" do
      delete session_path
      get bands_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
