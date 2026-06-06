FactoryBot.define do
  factory :music_version do
    music
    name { "Original" }
    lyrics { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    chords { nil }
    primary { false }

    trait :primary do
      primary { true }
    end

    trait :with_chords do
      chords { "[Verse]\nAm G C F" }
    end
  end
end
