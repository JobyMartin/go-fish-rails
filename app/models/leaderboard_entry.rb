# Backed by the `leaderboard_entries` database view (db/views/leaderboard_entries_v01.sql),
# so this reads like any other table. See docs/leaderboard.md.
class LeaderboardEntry < ApplicationRecord
  # Without a floor, one lucky win reads as 100% and outranks a 400-of-600 record.
  MINIMUM_RANKED_GAMES = 5
  UNRANKED = "—".freeze

  # Ties fall back to the tighter record, then username, so identical requests return an
  # identical board. Ordering lives here rather than in the view: it is a display rule.
  scope :ranked, -> { order(games_won: :desc, games_played: :asc, username: :asc) }

  def readonly? = true

  def win_percentage
    return if games_played < MINIMUM_RANKED_GAMES

    (games_won.to_f / games_played * 100).round
  end
end
