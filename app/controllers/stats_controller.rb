
class StatsController < ApplicationController
  NO_STATS = "0%"

  def index
    @user = Current.session.user
    @win_percentage = win_percentage
    @games_won = winner_count
  end

  private

  def win_percentage
    return NO_STATS if player_count.zero?
    "#{((winner_count / player_count) * 100).to_i}%"
  end

  def player_count = @user.players.count.to_f
  def winner_count = @user.players.count { it.winner }
end
