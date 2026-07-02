class Game < ApplicationRecord
  enum :game_type, {
    go_fish: 0,
    secret_hitler: 1
  }
end
