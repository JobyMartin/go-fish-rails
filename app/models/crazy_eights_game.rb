class CrazyEightsGame < Game
  serialize :game_state, coder: CrazyEights::Game
end