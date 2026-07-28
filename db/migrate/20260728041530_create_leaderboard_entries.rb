class CreateLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    create_view :leaderboard_entries
  end
end
