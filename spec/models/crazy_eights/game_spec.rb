require 'rails_helper'

RSpec.describe CrazyEights::Game, type: :model do
  let(:num_players) { 5 }
  let!(:players) { Array.new(num_players) { |id| CrazyEights::Player.new(id) } }
  let!(:crazy_eights_game) { described_class.new(players) }

  describe '#deal!' do
    let(:small_game_hand) { 5 }
    let(:large_game_hand) { 7 }
    context 'when there are more than 2 players' do
      it 'deals the players 5 cards' do
        crazy_eights_game.deal!
        dealt_players_hands = crazy_eights_game.players.map(&:hand)

        expect(dealt_players_hands.first.count).to eq small_game_hand
        dealt_players_hands.first.each do
          expect(it).to be_a CrazyEights::Card
        end
      end
    end

    context 'when there are 2 players or less' do
      let(:num_players) { 2 }
      let!(:players) { Array.new(num_players) { |id| CrazyEights::Player.new(id) } }
      let!(:crazy_eights_game) { described_class.new(players) }

      it 'deals the players 7 cards' do
        crazy_eights_game.deal!
        dealt_players_hands = crazy_eights_game.players.map(&:hand)

        expect(dealt_players_hands.first.count).to eq large_game_hand
        dealt_players_hands.first.each do
          expect(it).to be_a CrazyEights::Card
        end
      end
    end
  end

  describe '#find_player' do
    let(:user_id) { 0 }
    it 'returns the player with the name in question' do
      expect(crazy_eights_game.find_player(user_id)).to eq crazy_eights_game.players.first
    end
  end
end