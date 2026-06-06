require "rails_helper"

RSpec.describe Music, type: :model do
  subject(:music) { build(:music) }

  it { is_expected.to be_valid }

  describe "validations" do
    it "requires a title" do
      music.title = ""
      expect(music).not_to be_valid
    end

    it "requires an artist" do
      music.artist = ""
      expect(music).not_to be_valid
    end
  end

  describe "#musical_key" do
    it "returns nil when key_name is blank" do
      music.key_name = nil
      expect(music.musical_key).to be_nil
    end

    it "formats major key correctly" do
      music.key_name = "G"
      music.key_mode = "major"
      expect(music.musical_key).to eq("G Major")
    end

    it "formats minor key correctly" do
      music.key_name = "A"
      music.key_mode = "minor"
      expect(music.musical_key).to eq("A Minor")
    end
  end

  describe "#bpm_display" do
    it "returns nil when bpm is blank" do
      music.bpm = nil
      expect(music.bpm_display).to be_nil
    end

    it "returns integer string for decimal bpm" do
      music.bpm = 120.5
      expect(music.bpm_display).to eq("120")
    end
  end

  describe "#has_chords?" do
    it "returns false when chords is blank" do
      music.chords = nil
      expect(music.has_chords?).to be false
    end

    it "returns true when chords are present" do
      music.chords = "Am G C F"
      expect(music.has_chords?).to be true
    end
  end

  describe "#display_content" do
    it "returns chords when present" do
      music.chords = "Am G C F"
      music.lyrics = "Some lyrics"
      expect(music.display_content).to eq("Am G C F")
    end

    it "falls back to lyrics when no chords" do
      music.chords = nil
      music.lyrics = "Some lyrics"
      expect(music.display_content).to eq("Some lyrics")
    end
  end

  describe "versions" do
    it "creates an original version from the music content" do
      music = create(:music, lyrics: "Some lyrics", chords: "Am G")

      expect(music.versions.count).to eq(1)
      expect(music.primary_version.name).to eq("Original")
      expect(music.primary_version.lyrics).to eq("Some lyrics")
      expect(music.primary_version.chords).to eq("Am G")
    end

    it "returns a user's preferred version as their default" do
      user = create(:user)
      music = create(:music, lyrics: "Original lyrics")
      alternate = create(:music_version, music: music, name: "Lower key", lyrics: "Lower lyrics")
      create(:music_version_preference, user: user, music: music, music_version: alternate)

      expect(music.default_version_for(user)).to eq(alternate)
      expect(music.lyrics_for(user)).to eq("Lower lyrics")
    end

    it "falls back to the shared primary version when the user has no preference" do
      user = create(:user)
      music = create(:music, lyrics: "Original lyrics")

      expect(music.default_version_for(user)).to eq(music.primary_version)
      expect(music.lyrics_for(user)).to eq("Original lyrics")
    end

    it "syncs legacy content edits into the primary version" do
      music = create(:music, lyrics: "Old lyrics", chords: nil)

      music.update!(lyrics: "New lyrics", chords: "C G")

      expect(music.primary_version.reload.lyrics).to eq("New lyrics")
      expect(music.primary_version.chords).to eq("C G")
    end
  end

  describe "#labels_text" do
    it "returns comma-separated labels" do
      music.labels = [ "rock", "acoustic" ]

      expect(music.labels_text).to eq("rock, acoustic")
    end
  end

  describe "#labels_text=" do
    it "normalizes comma-separated labels" do
      music.labels_text = " Rock, acoustic, rock, Punk "
      music.validate

      expect(music.labels).to eq([ "rock", "acoustic", "punk" ])
    end

    it "splits labels into single words" do
      music.labels_text = "Rock Nacional, indie pop"
      music.validate

      expect(music.labels).to eq([ "rock", "nacional", "indie", "pop" ])
    end
  end
end
