class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :players
  has_many :games, through: :players

  attribute :confirm_password

  MINIMUM_RANKED_GAMES = 5
  UNRANKED = "—".freeze

  validates :email_address, presence: true, uniqueness: { case_insensitive: true }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 30 }

  has_secure_password
  validates :password, length: { minimum: 8 }, allow_nil: true, comparison: { equal_to: :confirm_password }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.strip }

  def games_played = players.count

  def games_won = players.count { it.winner }

  def win_percentage
    return if games_played < MINIMUM_RANKED_GAMES

    (games_won.to_f / games_played * 100).round
  end

  def time_played = games.filter_map { it.duration }.sum
end
