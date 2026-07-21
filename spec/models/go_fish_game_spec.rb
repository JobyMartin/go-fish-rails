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

  describe 'shared contract' do
    let(:game) { create(:game, type: 'GoFishGame') }

    before do
      create(:player, game:)
      create(:player, game:)
      game.start
      game.play_turn(game.game_state.players.last.id, 'A')
      game.save!
    end

    it_behaves_like 'a persisted card game'
  end

  describe '#build_game' do
    it 'builds a GoFish::Game domain object' do
      game = create(:game, type: 'GoFishGame')
      create(:player, game:)
      game.start
      expect(game.game_state).to be_a GoFish::Game
    end
  end

  describe 'an unstarted game' do
    it 'serializes game_state as nil' do
      game = create(:game, type: 'GoFishGame')
      expect(game.reload.game_state).to be_nil
    end
  end
end
