FactoryBot.define do
  factory :player do
    user
    game

    trait :winner do
      winner { true }
    end
  end
end
