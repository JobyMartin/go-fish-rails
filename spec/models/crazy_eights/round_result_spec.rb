require 'rails_helper'

RSpec.describe CrazyEights::RoundResult, type: :model do
  describe '#for_other_players' do
    let(:current_player) { CrazyEights::Player.new(0, 'Joby') }
    let(:card_placed) { Card.new }
    context 'when a player places a card' do
      it 'returns a message saying that placed said card' do
        round_result = CrazyEights::RoundResult.new(
          current_player: current_player,
          card_placed: card_placed
        )

        message = 'Joby placed a A of Spades'
        expect(round_result.for_other_players.first).to eq message
      end
    end

    context 'when a player places an eight/wild card' do
      let(:wild) { true }
      let(:suit_choice) { 'Hearts' }
      let(:card_placed) { Card.new('8') }

      it 'returns a message with the suit selection' do
        round_result = CrazyEights::RoundResult.new(
          current_player: current_player,
          card_placed: card_placed,
          wild: wild,
          suit_choice: suit_choice
        )

        message = 'They chose the suit of Hearts'
        expect(round_result.for_other_players.last).to eq message
      end
    end
  end
end