class GoFishGame < Game
  serialize :game_state, coder: GoFish::Game

  def play_turn(inquired_player_id, inquired_rank)
    if game_state.current_player.hand_size == 0
      game_state.fish_and_skip
    else
      game_state.play_turn(inquired_player_id, inquired_rank.chars.first)
    end
  end
end
