FactoryBot.define do
  factory :player do
    user
    game

    trait :winner do
      winner { true }
    end

    trait :in_finished_game do
      after(:create) do |player|
        ended = 1.day.ago
        player.game.update!(started_at: ended - FinishedGame::DURATION, ended_at: ended)
      end
    end
  end
end
