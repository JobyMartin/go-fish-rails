class UpdateLeaderboardEntriesToVersion2 < ActiveRecord::Migration[8.1]
  def change
    update_view :leaderboard_entries, version: 2, revert_to_version: 1
  end
end
