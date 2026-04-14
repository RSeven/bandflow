require "rails_helper"

RSpec.describe "Musics", type: :request do
  let(:user) { create(:user) }
  let(:band) do
    b = create(:band)
    create(:band_membership, user: user, band: b)
    b
  end
  let(:music) { create(:music, band: band) }

  before { sign_in(user) }

  describe "GET /bands/:band_id/musics/new" do
    it "returns 200" do
      get new_band_music_path(band)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /bands/:band_id/musics/:id" do
    it "returns 200" do
      get band_music_path(band, music)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /bands/:band_id/musics" do
    it "creates a music and redirects" do
      expect {
        post band_musics_path(band), params: {
          music: { title: "Stairway to Heaven", artist: "Led Zeppelin" }
        }
      }.to change(Music, :count).by(1)
      expect(response).to redirect_to(band_music_path(band, Music.last))
    end

    it "renders new on invalid params" do
      post band_musics_path(band), params: { music: { title: "", artist: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /bands/:band_id/musics/:id" do
    it "updates the music" do
      patch band_music_path(band, music), params: { music: { title: "New Title" } }
      expect(music.reload.title).to eq("New Title")
    end
  end

  describe "DELETE /bands/:band_id/musics/:id" do
    it "destroys the music" do
      music # ensure exists
      expect { delete band_music_path(band, music) }.to change(Music, :count).by(-1)
      expect(response).to redirect_to(band_path(band))
    end
  end

  describe "GET /bands/:band_id/musics/search" do
    it "returns JSON array" do
      allow(ItunesSearchService).to receive(:search).and_return([
        ItunesSearchService::Result.new(
          track_name: "Bohemian Rhapsody",
          artist_name: "Queen",
          artwork_url: "https://example.com/art.jpg",
          preview_url: nil
        )
      ])

      get search_band_musics_path(band), params: { q: "Bohemian" },
          headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.first["track_name"]).to eq("Bohemian Rhapsody")
    end

    it "returns empty array for short query" do
      get search_band_musics_path(band), params: { q: "a" },
          headers: { "Accept" => "application/json" }
      expect(JSON.parse(response.body)).to eq([])
    end
  end

  describe "POST /bands/:band_id/musics/fetch_metadata" do
    it "returns metadata JSON including chords" do
      allow(MusicMetadataService).to receive(:fetch).and_return(
        MusicMetadataService::Result.new(
          spotify_track_id: "abc123",
          spotify_url: "https://open.spotify.com/track/abc123",
          youtube_url: "https://youtube.com/watch?v=xyz",
          lyrics: "Some lyrics",
          chords: "Am G C F",
          bpm: 120.0,
          key_name: "G",
          key_mode: "major"
        )
      )

      post fetch_metadata_band_musics_path(band),
           params: { title: "Bohemian Rhapsody", artist: "Queen" },
           headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["bpm"]).to    eq(120.0)
      expect(body["key_name"]).to eq("G")
      expect(body["chords"]).to  eq("Am G C F")
    end

    it "returns 422 when title or artist is missing" do
      post fetch_metadata_band_musics_path(band),
           params: { title: "", artist: "" },
           headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
