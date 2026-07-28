class LeaderboardController < ApplicationController
  def index
    @entries = LeaderboardEntry.ranked
  end
end
