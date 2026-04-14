FactoryBot.define do
  factory :setlist do
    band
    title            { "#{Faker::Music.genre} Night" }
    performance_date { Faker::Date.forward(days: 30) }
    notes            { nil }
  end
end
