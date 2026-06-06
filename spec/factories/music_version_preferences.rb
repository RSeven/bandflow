FactoryBot.define do
  factory :music_version_preference do
    user
    music
    music_version { association(:music_version, music: music) }
  end
end
