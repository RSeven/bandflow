require "rails_helper"

RSpec.describe MusicSearchQuery do
  describe ".call" do
    it "matches title or artist with plain text" do
      matching_music = create(:music, title: "Quiet Song", artist: "Artist", labels: [ "acoustic" ])
      create(:music, title: "Loud Song", artist: "Artist", labels: [ "quiet" ])

      expect(described_class.call(Music.all, "quiet")).to contain_exactly(matching_music)
    end

    it "does not match labels with plain text" do
      create(:music, title: "Quiet Song", artist: "Artist", labels: [ "acoustic" ])

      expect(described_class.call(Music.all, "acoustic")).to be_empty
    end

    it "matches labels by hashtag prefix" do
      matching_music = create(:music, title: "Quiet Song", artist: "Artist", labels: [ "acoustic" ])
      create(:music, title: "Loud Song", artist: "Artist", labels: [ "punk" ])

      expect(described_class.call(Music.all, "#aco")).to contain_exactly(matching_music)
    end

    it "ignores a bare hashtag while the user is starting a tag search" do
      music = create(:music, title: "Quiet Song", artist: "Artist")

      expect(described_class.call(Music.all, "#")).to include(music)
    end

    it "matches label prefixes from the beginning of each label" do
      nacional = create(:music, title: "Local Song", artist: "Artist", labels: [ "nacional" ])
      create(:music, title: "Global Song", artist: "Artist", labels: [ "internacional" ])

      expect(described_class.call(Music.all, "#nac")).to contain_exactly(nacional)
    end

    it "matches the virtual new tag by canonical prefix" do
      recent_music = create(:music, title: "Recent Song", artist: "Artist")
      old_music = create(:music, title: "Old Song", artist: "Artist")
      old_music.update_column(:created_at, 61.days.ago)

      expect(described_class.call(Music.all, "#ne")).to contain_exactly(recent_music)
    end

    it "matches the virtual new tag by localized prefix" do
      recent_music = create(:music, title: "Recent Song", artist: "Artist")
      old_music = create(:music, title: "Old Song", artist: "Artist")
      old_music.update_column(:created_at, 61.days.ago)

      I18n.with_locale(:"pt-BR") do
        expect(described_class.call(Music.all, "#nov")).to contain_exactly(recent_music)
      end
    end

    it "keeps the provided scope boundary" do
      band = create(:band)
      matching_music = create(:music, band: band, title: "Quiet Song", artist: "Artist")
      create(:music, title: "Quiet Song", artist: "Artist")

      expect(described_class.call(band.musics, "quiet")).to contain_exactly(matching_music)
    end
  end
end
