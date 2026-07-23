require 'rails_helper'

RSpec.describe Rummy::RoundResult, type: :model do
  let(:current_player) { Rummy::Player.new(0, 'Joby') }
  let(:card_discarded) { Card.new('7', 'Spades') }

  describe '#feed_lines' do
    it 'describes what the player discarded' do
      round_result = Rummy::RoundResult.new(current_player: current_player, card_discarded: card_discarded)

      expect(round_result.feed_lines.first.text).to eq 'Joby discarded a 7 of Spades'
    end
  end

  describe '.load' do
    it 'rebuilds a round result from a hash' do
      hash = { 'current_player' => current_player.as_json, 'card_discarded' => card_discarded.as_json }
      loaded = Rummy::RoundResult.load(hash)

      expect(loaded.current_player.name).to eq 'Joby'
      expect(loaded.card_discarded).to eq card_discarded
    end
  end
end
