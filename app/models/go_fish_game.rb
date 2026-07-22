class GoFishGame < Game
  serialize :game_state, coder: GoFish::Game

  def play_turn(params)
    if game_state.current_player.hand_size == 0
      game_state.fish_and_skip
    else
      game_state.play_turn(params[:player].to_i, params[:rank].chars.first)
    end
  end

  private

  def build_game
    GoFish::Game.new(users.map { GoFish::Player.new(it.id) })
  end
end
