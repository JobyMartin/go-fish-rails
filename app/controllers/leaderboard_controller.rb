class LeaderboardController < ApplicationController
  def index
    @users = User.all.sort_by { -it.games_won }
  end
end
