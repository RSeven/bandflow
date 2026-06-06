require "rails_helper"

RSpec.describe MusicVersion, type: :model do
  let(:music) { create(:music, lyrics: "Original lyrics", chords: "C G") }

  it "requires a name" do
    version = build(:music_version, music: music, name: "")

    expect(version).not_to be_valid
  end

  it "syncs primary version content back to the music" do
    version = create(:music_version, :primary, music: music, name: "Acoustic", lyrics: "Soft lyrics", chords: "Am F")

    expect(music.reload.lyrics).to eq("Soft lyrics")
    expect(music.chords).to eq("Am F")
    expect(music.primary_version).to eq(version)
  end

  it "keeps only one primary version" do
    original = music.primary_version
    alternate = create(:music_version, music: music, name: "Live")

    alternate.update!(primary: true)

    expect(original.reload).not_to be_primary
    expect(alternate.reload).to be_primary
  end

  it "keeps a primary version when the current primary is deleted" do
    original = music.primary_version
    alternate = create(:music_version, music: music, name: "Live", lyrics: "Live lyrics")

    original.destroy!

    expect(alternate.reload).to be_primary
    expect(music.reload.lyrics).to eq("Live lyrics")
  end
end
