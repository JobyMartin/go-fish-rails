class Game < ApplicationRecord
  include ActionView::RecordIdentifier
  # Seat order is join order: unordered, Postgres is free to hand back rows in any order, which
  # makes both the waiting room list and whoever ends up as the first current_player random.
  has_many :players, -> { order(:id) }, inverse_of: :game
  has_many :users, through: :players

  after_update_commit { broadcast_refresh_later_to self }
  after_create_commit :broadcast_game_update
  after_update_commit :broadcast_status

  MINIMUM_PLAYERS = 2
  WAITING_FOR_PLAYERS_MESSAGE = "Waiting for at least #{MINIMUM_PLAYERS} players to join..."
  NOT_ENOUGH_PLAYERS_MESSAGE = "You need at least #{MINIMUM_PLAYERS} players to start a game."
  WAITING_MESSAGE = 'Waiting...'
  IN_PROGRESS_MESSAGE = 'In progress'
  FINISHED_MESSAGE = 'Finished'
  PLAYABLE_TYPES = {
    'GoFishGame' => 'Go Fish', 'CrazyEightsGame' => 'Crazy Eights', 'RummyGame' => 'Rummy'
  }.freeze

  def self.playable_types
    PLAYABLE_TYPES
  end

  def self.playable_class(type)
    type.constantize if playable_types.key?(type)
  end

  def status
    return WAITING_MESSAGE if started_at.nil?
    return IN_PROGRESS_MESSAGE if !started_at.nil? && ended_at.nil?
    return FINISHED_MESSAGE unless ended_at.nil?
  end

  def startable?
    users.size >= MINIMUM_PLAYERS
  end

  def start
    return false unless startable?

    self.started_at = Time.current
    self.game_state = build_game
    game_state.deal!
    save!
  end

  def end
    self.ended_at = Time.current
  end

  def finish!
    return if ended_at.present?

    self.end
    record_winner
    save!
  end

  def duration
    return unless started_at && ended_at

    ended_at - started_at
  end

  private

  def record_winner
    players.find_by(user_id: game_state.winner.id)&.update!(winner: true)
  end

  def broadcast_status
    broadcast_remove_to(
      'games',
      target: dom_id(self),
      )
  end

  def broadcast_game_update
    broadcast_append_later_to(
      'games',
      target: 'all-games-list',
      partial: 'application/game-card',
      locals: { name: self.name, status: self.status, button_text: 'Join', game: self }
    )
  end
end
