class LeaderboardEntry < ApplicationRecord
  UNRANKED = "—".freeze

  scope :ranked, -> { order(games_won: :desc, games_played: :asc, username: :asc) }

  DEFAULT_SORT = [ "games_won desc", "games_played asc", "username asc" ].freeze

  def self.ransackable_attributes(_auth_object = nil)
    %w[rank username games_played games_won time_played]
  end

  def self.ransackable_associations(_auth_object = nil) = []

  def self.ranked_search(params)
    search = ransack(params)
    search.sorts = DEFAULT_SORT unless search.sorts.any?(&:attr_name)
    search
  end

  def readonly? = true
end
