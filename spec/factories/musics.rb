FactoryBot.define do
  factory :music do
    band
    title  { Faker::Music::RockBand.song }
    artist { Faker::Music.band }
    lyrics { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    chords { nil }
    bpm    { rand(60..180).to_f }
    key_name { Music::PITCH_CLASSES.sample }
    key_mode { %w[major minor].sample }

    trait :with_chords do
      chords { "[Verse]\nAm G C F\n\n[Chorus]\nC G Am F" }
    end

    trait :with_spotify do
      spotify_url      { "https://open.spotify.com/track/#{SecureRandom.hex(11)}" }
      spotify_track_id { SecureRandom.hex(11) }
    end
  end
end
