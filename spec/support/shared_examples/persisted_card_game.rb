
RSpec.shared_examples 'a persisted card game' do
  it 'deals cards to every player' do
    expect(game.game_state.players).to all(satisfy { it.hand.any? })
  end

  it 'finds a player by user id' do
    player = game.game_state.players.first
    expect(game.game_state.find_player(player.id)).to eq player
  end

  it 'exposes the current player' do
    expect(game.game_state.current_player).to be_present
  end

  it 'tracks round results' do
    expect(game.game_state.round_results).to be_an(Array)
  end

  it 'answers game_over?' do
    expect(game.game_state.game_over?).to be_in [ true, false ]
  end

  it 'round-trips game_state through the DB with fidelity' do
    before_json = game.game_state.as_json
    expect(game.reload.game_state.as_json).to eq before_json
  end

  it 'reports a winner once the game is over' do
    game.game_state.current_player.hand = []
    expect(game.game_state.winner).to be_present
  end
end
