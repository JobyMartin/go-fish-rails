class Player < ApplicationRecord
  JOINED_ERROR_MESSAGE = 'You already joined the game'.freeze

  belongs_to :game
  belongs_to :user

  validates :game_id, uniqueness: { scope: :user_id, message: JOINED_ERROR_MESSAGE }
end
