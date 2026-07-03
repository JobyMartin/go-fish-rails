FactoryBot.define do
  factory :game do
    name { 'My game' }
    game_type { 'go_fish' }

    trait :in_progress do
      started_at { 1.day.ago }
    end

    trait :ended do
      started_at { 2.days.ago }
      ended_at { 1.day.ago }
    end
  end
end
