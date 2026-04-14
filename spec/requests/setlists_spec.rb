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

    it "shows only musics that are not already in the setlist" do
      included_music = create(:music, band: band, title: "Available Song")
      excluded_music = create(:music, band: band, title: "Already Added")
      setlist.setlist_items.create!(item: excluded_music)

      get band_setlist_path(band, setlist)

      expect(response.body).to include("Available Song")
      expect(response.body).not_to include(%(params[item_id]" value="#{excluded_music.id}"))
    end

    it "paginates and filters add-music and add-event panels" do
      9.times do |i|
        create(:music, band: band, title: format("Song %02d", i), artist: "Artist")
        create(:event, band: band, title: format("Event %02d", i))
      end

      get band_setlist_path(band, setlist), params: {
        music_page: 2,
        event_page: 2,
        music_query: "Song 08",
        event_query: "Event 08"
      }

      expect(response.body).to include("Search by title or artist")
      expect(response.body).to include("Search by title or description")
      expect(response.body).to include("Song 08")
      expect(response.body).not_to include("Song 00")
      expect(response.body).to include("Event 08")
      expect(response.body).not_to include("Event 00")
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
      expect(response.body).to include("Scroll Up")
      expect(response.body).to include("Scroll Down")
    end
  end

  describe "POST /bands/:band_id/setlists/:setlist_id/setlist_items" do
    it "removes an added music from the add-music list in the turbo response" do
      added_music = create(:music, band: band, title: "Song To Add")
      other_music = create(:music, band: band, title: "Still Available")

      post band_setlist_setlist_items_path(band, setlist),
           params: { item_type: "Music", item_id: added_music.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).not_to include(%(name="item_id" value="#{added_music.id}" autocomplete="off"))
      expect(response.body).to include("Still Available")
    end

    it "preserves sidebar search and pagination state in turbo responses" do
      9.times do |i|
        create(:music, band: band, title: format("Song %02d", i), artist: "Artist")
        create(:event, band: band, title: format("Event %02d", i))
      end

      added_music = Music.find_by!(title: "Song 08")

      post band_setlist_setlist_items_path(band, setlist),
           params: {
             item_type: "Music",
             item_id: added_music.id,
             music_page: 2,
             music_query: "Song 08",
             event_page: 2,
             event_query: "Event 08"
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Event 08")
      expect(response.body).to include(%(value="Song 08"))
      expect(response.body).to include(%(value="Event 08"))
    end
  end

  describe "DELETE /bands/:band_id/setlists/:id" do
    it "destroys setlist" do
      setlist # ensure exists
      expect { delete band_setlist_path(band, setlist) }.to change(Setlist, :count).by(-1)
    end
  end
end
