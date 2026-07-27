class Player < ApplicationRecord
  JOINED_ERROR_MESSAGE = 'You already joined the game'.freeze
  NOT_STARTED_ERROR_MESSAGE = 'This game has started'

  belongs_to :game
  belongs_to :user

  validates :game_id, uniqueness: { scope: :user_id, message: JOINED_ERROR_MESSAGE }
  validate :not_started, on: :create

  private

  def not_started
    if !game.started_at.nil?
      errors.add(:base, NOT_STARTED_ERROR_MESSAGE)
    end
  end
end
