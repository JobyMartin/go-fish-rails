class Game < ApplicationRecord
  include ActionView::RecordIdentifier
  has_many :players
  has_many :users, through: :players

  after_update_commit { broadcast_refresh_to self }
  after_create_commit :broadcast_game_update
  after_update_commit :broadcast_status

  WAITING_MESSAGE = 'Waiting...'
  IN_PROGRESS_MESSAGE = 'In progress'
  FINISHED_MESSAGE = 'Finished'
  GO_FISH_GAME_TYPE = 'GoFishGame'


  def status
    return WAITING_MESSAGE if started_at.nil?
    return IN_PROGRESS_MESSAGE if !started_at.nil? && ended_at.nil?
    return FINISHED_MESSAGE unless ended_at.nil?
  end

  def start
    self.started_at = Time.current
    self.game_state = build_game
    game_state.deal!
    save!
  end

  def end
    self.ended_at = Time.current
  end

  private

  def broadcast_status
    broadcast_remove_to(
      'games',
      target: dom_id(self),
      )
  end

  def broadcast_game_update
    broadcast_append_to(
      'games',
      target: 'all-games-list',
      partial: 'application/game-card',
      locals: { name: self.name, status: self.status, button_text: 'Join', game: self }
    )
  end

  def build_game
    if type == GO_FISH_GAME_TYPE
      GoFish::Game.new(users.map { |user| GoFish::Player.new(user.id) })
    else
      CrazyEights::Game.new(users.map { |user| CrazyEights::Player.new(user.id) })
    end
  end
end
