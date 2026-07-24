require 'rails_helper'

RSpec.describe Rummy::HandSorter, type: :model do
  describe '#sorted' do
    it 'puts a set in the making before the rest, which stay suit/rank sorted' do
      cards = [ Card.new('2', 'Hearts'), Card.new('5', 'Clubs'), Card.new('5', 'Diamonds') ]

      sorted = Rummy::HandSorter.new(cards).sorted

      expect(sorted).to eq [ Card.new('5', 'Diamonds'), Card.new('5', 'Clubs'), Card.new('2', 'Hearts') ]
    end

    it 'puts a run in the making before the rest' do
      cards = [ Card.new('K', 'Spades'), Card.new('3', 'Hearts'), Card.new('4', 'Hearts') ]

      sorted = Rummy::HandSorter.new(cards).sorted

      expect(sorted).to eq [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('K', 'Spades') ]
    end

    it 'orders multiple groups by size, largest first' do
      cards = [
        Card.new('3', 'Hearts'), Card.new('4', 'Hearts'),
        Card.new('9', 'Clubs'), Card.new('9', 'Diamonds'), Card.new('9', 'Spades')
      ]

      sorted = Rummy::HandSorter.new(cards).sorted

      expect(sorted).to eq [
        Card.new('9', 'Diamonds'), Card.new('9', 'Spades'), Card.new('9', 'Clubs'),
        Card.new('3', 'Hearts'), Card.new('4', 'Hearts')
      ]
    end

    it 'lets a set claim a card instead of an overlapping run' do
      cards = [
        Card.new('5', 'Hearts'), Card.new('5', 'Diamonds'), Card.new('5', 'Clubs'),
        Card.new('6', 'Hearts'), Card.new('7', 'Hearts')
      ]

      sorted = Rummy::HandSorter.new(cards).sorted

      expect(sorted).to eq [
        Card.new('5', 'Diamonds'), Card.new('5', 'Hearts'), Card.new('5', 'Clubs'),
        Card.new('6', 'Hearts'), Card.new('7', 'Hearts')
      ]
    end

    it 'leaves an ungrouped hand sorted by suit then rank' do
      cards = [ Card.new('K', 'Clubs'), Card.new('A', 'Diamonds'), Card.new('2', 'Hearts') ]

      sorted = Rummy::HandSorter.new(cards).sorted

      expect(sorted).to eq [
        Card.new('A', 'Diamonds'), Card.new('2', 'Hearts'), Card.new('K', 'Clubs')
      ]
    end
  end
end
