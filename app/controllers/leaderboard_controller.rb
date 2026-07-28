class LeaderboardController < ApplicationController
  def index
    @search = LeaderboardEntry.ranked_search(params[:q])
  end
end
