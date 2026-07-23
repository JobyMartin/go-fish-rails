require 'rails_helper'

RSpec.describe RummyGame, type: :model do
  describe '#build_game' do
    it 'builds a Rummy::Game domain object with a player per user' do
      game = create(:game, type: 'RummyGame')
      create(:player, game:)

      game.start

      expect(game.game_state).to be_a Rummy::Game
      expect(game.game_state.players.count).to eq game.players.count
    end
  end

  describe '#play_turn' do
    let(:game) { create(:game, type: 'RummyGame') }

    before do
      create(:player, game:)
      game.start
    end

    it 'does not raise and does not change game state' do
      before_json = game.game_state.as_json
      expect { game.play_turn(move: 'draw', source: 'deck') }.not_to raise_error
      expect(game.game_state.as_json).to eq before_json
    end
  end

  describe 'shared contract' do
    let(:game) { create(:game, type: 'RummyGame') }

    before do
      create(:player, game:)
      create(:player, game:)
      game.start
      game.save!
    end

    it_behaves_like 'a persisted card game'
  end
end
