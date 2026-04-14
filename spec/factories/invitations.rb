FactoryBot.define do
  factory :invitation do
    band
    association :invited_by, factory: :user
    used_at { nil }
  end
end
