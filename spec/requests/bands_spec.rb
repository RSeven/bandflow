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

    it "shows tab navigation for musics and setlists" do
      get band_path(band)

      expect(response.body).to include("Repertoire")
      expect(response.body).to include("Setlists")
      expect(response.body).to include("Search by title or artist")
    end

    it "paginates musics separately from setlists" do
      11.times do |i|
        create(:music, band: band, title: format("Song %02d", i), artist: "Artist")
      end
      11.times do |i|
        create(:setlist, band: band, title: format("Setlist %02d", i))
      end

      get band_path(band), params: { music_page: 2 }

      expect(response.body).to include("Song 10")
      expect(response.body).not_to include("Song 00")
      expect(response.body).to include("Page 2 of 2")
      expect(response.body).not_to include("Setlist 00")
    end

    it "preserves the other page param in pagination links" do
      11.times do |i|
        create(:music, band: band, title: format("Song %02d", i), artist: "Artist")
      end
      11.times do |i|
        create(:setlist, band: band, title: format("Setlist %02d", i))
      end

      get band_path(band), params: { music_page: 2, setlist_page: 2 }

      expect(response.body).to include(%(setlist_page=2))
      expect(response.body).to include(%(music_page=2))
    end

    it "shows the requested tab" do
      create(:setlist, band: band, title: "Festival Night")
      create(:music, band: band, title: "Hidden Song", artist: "Artist")

      get band_path(band), params: { tab: "setlists" }

      expect(response.body).to include("Festival Night")
      expect(response.body).not_to include("Hidden Song")
    end

    it "filters musics by title or artist" do
      create(:music, band: band, title: "Bohemian Rhapsody", artist: "Queen")
      create(:music, band: band, title: "Paranoid Android", artist: "Radiohead")

      get band_path(band), params: { tab: "musics", music_query: "queen" }

      expect(response.body).to include("Bohemian Rhapsody")
      expect(response.body).not_to include("Paranoid Android")
    end

    it "redirects to bands index for non-members" do
      other_band = create(:band)
      get band_path(other_band)
      expect(response).to redirect_to(bands_path)
    end

    it "switches the interface to brazilian portuguese" do
      patch locale_path, params: { locale: "pt-BR", redirect_path: band_path(band) }

      expect(response).to redirect_to(band_path(band))

      follow_redirect!

      expect(response.body).to include("Repertório")
      expect(response.body).to include("Idioma")
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
