FactoryBot.define do
  factory :event do
    band
    title       { [ "Interact with the crowd", "Ask people to follow Instagram", "Guitar solo", "Announce next show" ].sample }
    description { nil }
  end
end
