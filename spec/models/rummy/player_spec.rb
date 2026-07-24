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

  describe '#sort_hand!' do
    it 'orders the hand by suit then rank' do
      player.hand = [ Card.new('K', 'Clubs'), Card.new('A', 'Diamonds'), Card.new('2', 'Hearts') ]

      player.sort_hand!

      expect(player.hand).to eq [
        Card.new('A', 'Diamonds'), Card.new('2', 'Hearts'), Card.new('K', 'Clubs')
      ]
    end
  end

  describe '#smart_sort_hand!' do
    it 'groups a set in the making before the rest of the hand' do
      player.hand = [ Card.new('2', 'Hearts'), Card.new('5', 'Clubs'), Card.new('5', 'Diamonds') ]

      player.smart_sort_hand!

      expect(player.hand).to eq [
        Card.new('5', 'Diamonds'), Card.new('5', 'Clubs'), Card.new('2', 'Hearts')
      ]
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
