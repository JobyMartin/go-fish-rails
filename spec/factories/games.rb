FactoryBot.define do
  factory :game do
    type { 'GoFishGame' }
    initialize_with { type.present? ? type.constantize.new(attributes) : Game.new(attributes) }
    sequence :name do |n|
      "Game #{n}"
    end

    trait :in_progress do
      started_at { 1.day.ago }
    end

    trait :ended do
      started_at { 2.days.ago }
      ended_at { 1.day.ago }
    end
  end
end
