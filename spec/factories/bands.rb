FactoryBot.define do
  factory :band do
    name        { Faker::Music.band }
    description { Faker::Lorem.sentence }
  end
end
