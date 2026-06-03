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

    it "uses priority as tiebreaker within the same rehearsal date" do
      same_date = 1.week.ago.to_date
      create(:music, band: band, title: "Low Priority", artist: "Artist", rehearsal_priority: 2, last_rehearsed_at: same_date)
      create(:music, band: band, title: "High Priority", artist: "Artist", rehearsal_priority: 9, last_rehearsed_at: same_date)
      create(:music, band: band, title: "No Priority", artist: "Artist", rehearsal_priority: nil, last_rehearsed_at: same_date)

      get band_rehearsal_path(band)

      expect(response.body.index("High Priority")).to be < response.body.index("Low Priority")
      expect(response.body.index("Low Priority")).to be < response.body.index("No Priority")
    end

    it "respects user sort order over priority" do
      create(:music, band: band, title: "Old High Priority", artist: "Artist", rehearsal_priority: 10, last_rehearsed_at: 2.weeks.ago.to_date)
      create(:music, band: band, title: "New Low Priority", artist: "Artist", rehearsal_priority: 1, last_rehearsed_at: 1.day.ago.to_date)

      get band_rehearsal_path(band)

      expect(response.body.index("Old High Priority")).to be < response.body.index("New Low Priority")
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

  describe "PATCH /bands/:band_id/rehearse/musics/:music_id/priority" do
    it "sets the rehearsal priority" do
      music = create(:music, band: band, rehearsal_priority: nil)

      patch band_rehearsal_music_priority_path(band, music), params: { rehearsal_priority: "7" }

      expect(music.reload.rehearsal_priority).to eq(7)
    end

    it "clears the rehearsal priority when blank" do
      music = create(:music, band: band, rehearsal_priority: 5)

      patch band_rehearsal_music_priority_path(band, music), params: { rehearsal_priority: "" }

      expect(music.reload.rehearsal_priority).to be_nil
    end

    it "redirects to the index preserving query and sort params" do
      music = create(:music, band: band)

      patch band_rehearsal_music_priority_path(band, music), params: {
        rehearsal_priority: "3",
        q: "blues",
        sort: "newest"
      }

      expect(response).to redirect_to(band_rehearsal_path(band, q: "blues", sort: "newest"))
    end
  end
end
