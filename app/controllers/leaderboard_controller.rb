class LeaderboardController < ApplicationController
  def index
    @users = User.includes(:players, :games).sort_by { -it.games_won }
  end
end
