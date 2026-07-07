class Game < ApplicationRecord
  serialize :go_fish, coder: GoFish::Game
  has_many :players
  has_many :users, through: :players

  WAITING_MESSAGE = 'Waiting...'
  IN_PROGRESS_MESSAGE = 'In progress'
  FINISHED_MESSAGE = 'Finished'

  enum :game_type, {
    go_fish: 0,
    secret_hitler: 1
  }

  def status
    return WAITING_MESSAGE if started_at.nil?
    return IN_PROGRESS_MESSAGE if !started_at.nil? && ended_at.nil?
    return FINISHED_MESSAGE if !ended_at.nil?
  end

  def start
    self.started_at = Time.current
    self.go_fish = GoFish::Game.new(users.map { |user| GoFish::Player.new(user.id) })
    go_fish.deal!
    save!
  end

  def end
    self.ended_at = Time.current
  end
end
