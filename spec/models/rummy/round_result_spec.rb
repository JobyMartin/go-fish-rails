require 'rails_helper'

RSpec.describe Rummy::RoundResult, type: :model do
  let(:current_player) { Rummy::Player.new(0, 'Joby') }
  let(:card_discarded) { Card.new('7', 'Spades') }

  describe '#feed_lines' do
    it 'describes what the player discarded' do
      round_result = Rummy::RoundResult.new(current_player: current_player, card_discarded: card_discarded)

      expect(round_result.feed_lines.first.text).to eq 'Joby discarded a 7 of Spades'
    end

    it 'has a single action line when the player did not go out' do
      round_result = Rummy::RoundResult.new(current_player: current_player, card_discarded: card_discarded)

      expect(round_result.feed_lines.map(&:role)).to eq [ :action ]
    end

    context 'when the discard empties the player hand' do
      it 'adds a going out message' do
        round_result = Rummy::RoundResult.new(
          current_player: current_player, card_discarded: card_discarded, going_out: true
        )

        expect(round_result.feed_lines.last.text).to eq 'Joby went out and won!'
      end

      it 'marks the going out message as a game response' do
        round_result = Rummy::RoundResult.new(
          current_player: current_player, card_discarded: card_discarded, going_out: true
        )

        expect(round_result.feed_lines.last.role).to eq :game_response
      end
    end
  end

  describe '#feed_lines when taking from the discard pile' do
    let(:card_taken) { Card.new('9', 'Diamonds') }

    it 'describes what the player took' do
      round_result = Rummy::RoundResult.new(current_player: current_player, card_taken: card_taken)

      expect(round_result.feed_lines.first.text).to eq 'Joby took a 9 of Diamonds from the discard pile'
    end

    it 'has a single action line' do
      round_result = Rummy::RoundResult.new(current_player: current_player, card_taken: card_taken)

      expect(round_result.feed_lines.map(&:role)).to eq [ :action ]
    end
  end

  describe '.load' do
    it 'rebuilds a round result from a hash' do
      hash = { 'current_player' => current_player.as_json, 'card_discarded' => card_discarded.as_json }
      loaded = Rummy::RoundResult.load(hash)

      expect(loaded.current_player.name).to eq 'Joby'
      expect(loaded.card_discarded).to eq card_discarded
    end

    it 'rebuilds whether the player went out' do
      hash = {
        'current_player' => current_player.as_json, 'card_discarded' => card_discarded.as_json, 'going_out' => true
      }
      loaded = Rummy::RoundResult.load(hash)

      expect(loaded.going_out).to eq true
    end

    it 'rebuilds a round result describing a card taken from the discard pile' do
      card_taken = Card.new('9', 'Diamonds')
      hash = { 'current_player' => current_player.as_json, 'card_taken' => card_taken.as_json }
      loaded = Rummy::RoundResult.load(hash)

      expect(loaded.card_taken).to eq card_taken
    end
  end
end
