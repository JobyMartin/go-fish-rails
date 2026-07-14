class ArchiveGameJob < ApplicationJob
  queue_as :default

  def perform
    archive_stale_games
  end

  private

  def archive_stale_games
    Game.all.where(archived_at: nil).each do |game|
      game.archived_at = Time.current if stale_game?(game.updated_at)
      game.save
    end
  end

  def stale_game?(updated_at)
    updated_at <= 2.days.ago
  end
end
