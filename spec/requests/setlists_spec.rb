require "rails_helper"

RSpec.describe "Setlists", type: :request do
  let(:user)    { create(:user) }
  let(:band)    { b = create(:band); create(:band_membership, user: user, band: b); b }
  let(:setlist) { create(:setlist, band: band) }

  before { sign_in(user) }

  describe "GET /bands/:band_id/setlists/new" do
    it "returns 200" do
      get new_band_setlist_path(band)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /bands/:band_id/setlists/:id" do
    it "returns 200" do
      get band_setlist_path(band, setlist)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /bands/:band_id/setlists" do
    it "creates setlist and redirects" do
      expect {
        post band_setlists_path(band), params: { setlist: { title: "Tour Night" } }
      }.to change(Setlist, :count).by(1)
      expect(response).to redirect_to(band_setlist_path(band, Setlist.last))
    end
  end

  describe "GET /bands/:band_id/setlists/:id/present" do
    it "renders with presentation layout" do
      get present_band_setlist_path(band, setlist)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /bands/:band_id/setlists/:id" do
    it "destroys setlist" do
      setlist # ensure exists
      expect { delete band_setlist_path(band, setlist) }.to change(Setlist, :count).by(-1)
    end
  end
end
