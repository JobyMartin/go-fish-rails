require 'rails_helper'

RSpec.describe GoFishGame, type: :model do
  describe '#play_turn' do
    let(:game) { create(:game, type: 'GoFishGame') }

    before do
      create(:player, game:)
      create(:player, game:)
      game.start
    end

    it 'delegates a normal ask to the domain game_state' do
      state = game.game_state
      opponent = state.players.last
      expect { game.play_turn(opponent.id, 'A') }
        .to change { state.round_results.size }.by(1)
    end

    it 'fishes and skips when the current player has an empty hand' do
      state = game.game_state
      fisher = state.current_player
      fisher.hand = []
      game.play_turn(0, 'A')
      expect(fisher.hand_size).to eq 1
    end
  end
end
