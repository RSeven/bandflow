FactoryBot.define do
  factory :user do
    name          { Faker::Name.name }
    email_address { Faker::Internet.unique.email }
    password      { "password123" }
  end
end
