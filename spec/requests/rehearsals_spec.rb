require "rails_helper"

RSpec.describe "Rehearsals", type: :request do
  let(:user) { create(:user) }
  let(:band) do
    b = create(:band)
    create(:band_membership, user: user, band: b)
    b
  end

  before { sign_in(user) }

  describe "GET /bands/:band_id/rehearse" do
    it "lists repertoire musics with rehearsal status" do
      create(:music, band: band, title: "Older Song", artist: "Artist", last_rehearsed_at: 2.weeks.ago.to_date)
      create(:music, band: band, title: "Fresh Song", artist: "Artist", last_rehearsed_at: 1.day.ago.to_date)
      create(:music, band: band, title: "Never Song", artist: "Artist", last_rehearsed_at: nil)

      get band_rehearsal_path(band)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rehearse")
      expect(response.body).to include("Older Song")
      expect(response.body).to include("Fresh Song")
      expect(response.body).to include("Never rehearsed")
    end

    it "filters musics by title or artist" do
      create(:music, band: band, title: "Bohemian Rhapsody", artist: "Queen")
      create(:music, band: band, title: "Paranoid Android", artist: "Radiohead")

      get band_rehearsal_path(band), params: { q: "queen" }

      expect(response.body).to include("Bohemian Rhapsody")
      expect(response.body).not_to include("Paranoid Android")
    end

    it "orders by oldest rehearsed first by default" do
      create(:music, band: band, title: "Fresh Song", artist: "Artist", last_rehearsed_at: 1.day.ago.to_date)
      create(:music, band: band, title: "Never Song", artist: "Artist", last_rehearsed_at: nil)
      create(:music, band: band, title: "Older Song", artist: "Artist", last_rehearsed_at: 2.weeks.ago.to_date)

      get band_rehearsal_path(band)

      expect(response.body.index("Never Song")).to be < response.body.index("Older Song")
      expect(response.body.index("Older Song")).to be < response.body.index("Fresh Song")
    end

    it "orders by newest rehearsed first when requested" do
      create(:music, band: band, title: "Fresh Song", artist: "Artist", last_rehearsed_at: 1.day.ago.to_date)
      create(:music, band: band, title: "Never Song", artist: "Artist", last_rehearsed_at: nil)
      create(:music, band: band, title: "Older Song", artist: "Artist", last_rehearsed_at: 2.weeks.ago.to_date)

      get band_rehearsal_path(band), params: { sort: "newest" }

      expect(response.body.index("Fresh Song")).to be < response.body.index("Older Song")
      expect(response.body.index("Older Song")).to be < response.body.index("Never Song")
    end
  end

  describe "GET /bands/:band_id/rehearse/musics/:music_id" do
    it "shows a music in rehearsal mode" do
      music = create(:music, :with_chords, band: band, title: "Practice Song", artist: "Artist")

      get band_rehearsal_music_path(band, music)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rehearsal Mode")
      expect(response.body).to include("Practice Song")
      expect(response.body).to include("Mark Rehearsed")
    end
  end

  describe "PATCH /bands/:band_id/rehearse/musics/:music_id" do
    it "updates the last rehearsed date from the list" do
      music = create(:music, band: band, last_rehearsed_at: nil)

      patch band_rehearsal_music_path(band, music), params: {
        last_rehearsed_at: "2026-06-03",
        q: "song",
        sort: "newest"
      }

      expect(response).to redirect_to(band_rehearsal_path(band, q: "song", sort: "newest"))
      expect(music.reload.last_rehearsed_at).to eq(Date.new(2026, 6, 3))
    end

    it "marks the music as rehearsed now from rehearsal mode" do
      music = create(:music, band: band, last_rehearsed_at: nil)

      patch band_rehearsal_music_path(band, music), params: {
        mark_now: "1",
        return_to: "show"
      }

      expect(response).to redirect_to(band_rehearsal_music_path(band, music))
      expect(music.reload.last_rehearsed_at).to eq(Date.current)
    end
  end
end
