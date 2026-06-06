require "rails_helper"

RSpec.describe MusicVersionPreference, type: :model do
  it "requires the version to belong to the selected music" do
    music = create(:music)
    other_version = create(:music_version)
    preference = build(:music_version_preference, music: music, music_version: other_version)

    expect(preference).not_to be_valid
  end

  it "allows one preferred version per user and music" do
    user = create(:user)
    music = create(:music)
    version = music.primary_version
    create(:music_version_preference, user: user, music: music, music_version: version)
    duplicate = build(:music_version_preference, user: user, music: music, music_version: version)

    expect(duplicate).not_to be_valid
  end
end
