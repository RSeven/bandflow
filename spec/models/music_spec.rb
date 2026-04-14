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
end
