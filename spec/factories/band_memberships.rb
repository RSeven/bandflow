FactoryBot.define do
  factory :band_membership do
    user
    band
    role { "member" }

    trait :admin do
      role { "admin" }
    end
  end
end
