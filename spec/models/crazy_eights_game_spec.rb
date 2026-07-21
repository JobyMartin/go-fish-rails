require 'rails_helper'

RSpec.describe CrazyEightsGame, type: :model do
  describe '#play_turn' do
    let(:game) { create(:game, type: 'CrazyEightsGame') }

    before do
      create(:player, game:)
      create(:player, game:)
      game.start
    end

    it 'places a given card onto William and advances the turn' do
      state = game.game_state
      before_index = state.current_player_index
      card = state.current_player.hand.first
      game.play_turn(state.william.active_card, "#{card.rank} #{card.suit}")
      expect(state.william.active_card).to eq card
      expect(state.current_player_index).not_to eq before_index
    end

    it 'draws until a playable card when none is given' do
      state = game.game_state
      active = state.william.active_card
      game.play_turn(active)
      placed = state.william.active_card
      expect(placed.suit == active.suit || placed.rank == active.rank).to be true
    end
  end
end

