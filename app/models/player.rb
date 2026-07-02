class Player < ApplicationRecord
  belongs_to :game
  belongs_to :user

  validates :game_id, uniqueness: { scope: :user_id, message: 'You already joined the game' }
end
