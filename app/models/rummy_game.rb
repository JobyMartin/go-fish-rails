class RummyGame < Game
  serialize :game_state, coder: Rummy::Game

  def play_turn(params)
    params
  end

  private

  def build_game
    Rummy::Game.new(users.map { Rummy::Player.new(it.id) })
  end
end
