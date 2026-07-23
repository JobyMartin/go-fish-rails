require 'rails_helper'

RSpec.describe Rummy::Player, type: :model do
  let(:player) { Rummy::Player.new(1, 'Joby') }
  let(:card1) { Card.new('A', 'Spades') }
  let(:card2) { Card.new('K', 'Spades') }

  describe '#add_cards' do
    it 'adds cards to the hand' do
      player.add_cards([ card1, card2 ])
      expect(player.hand).to eq [ card1, card2 ]
    end
  end

  describe '.load' do
    it 'rebuilds a player with id, name, and hand from a hash' do
      hash = { 'id' => 1, 'name' => 'Joby', 'hand' => [ card1.as_json ] }
      loaded = Rummy::Player.load(hash)
      expect(loaded.id).to eq 1
      expect(loaded.name).to eq 'Joby'
      expect(loaded.hand).to eq [ card1 ]
    end
  end
end
