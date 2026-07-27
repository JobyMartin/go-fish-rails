require 'rails_helper'

RSpec.describe Rummy::Meld, type: :model do
  let(:card1) { Card.new('7', 'Spades') }
  let(:card2) { Card.new('8', 'Spades') }
  let(:card3) { Card.new('9', 'Spades') }

  describe '.load' do
    it "rebuilds a meld's cards from a hash" do
      hash = { 'cards' => [ card1.as_json, card2.as_json, card3.as_json ] }
      loaded = Rummy::Meld.load(hash)
      expect(loaded.cards).to eq [ card1, card2, card3 ]
    end
  end

  describe '.valid_set?' do
    it 'returns true for 3 cards of the same rank' do
      cards = [ Card.new('7', 'Spades'), Card.new('7', 'Hearts'), Card.new('7', 'Clubs') ]
      expect(Rummy::Meld.valid_set?(cards)).to eq true
    end

    it 'returns true for 4 cards of the same rank' do
      cards = [
        Card.new('7', 'Spades'), Card.new('7', 'Hearts'), Card.new('7', 'Clubs'), Card.new('7', 'Diamonds')
      ]
      expect(Rummy::Meld.valid_set?(cards)).to eq true
    end

    it 'returns false for 2 cards of the same rank' do
      cards = [ Card.new('7', 'Spades'), Card.new('7', 'Hearts') ]
      expect(Rummy::Meld.valid_set?(cards)).to eq false
    end

    it 'returns false when ranks differ' do
      cards = [ Card.new('7', 'Spades'), Card.new('7', 'Hearts'), Card.new('8', 'Clubs') ]
      expect(Rummy::Meld.valid_set?(cards)).to eq false
    end
  end

  describe '.valid_run?' do
    it 'returns true for consecutive same-suit cards, aces low' do
      cards = [ Card.new('A', 'Hearts'), Card.new('2', 'Hearts'), Card.new('3', 'Hearts') ]
      expect(Rummy::Meld.valid_run?(cards)).to eq true
    end

    it 'returns false for an ace-high run' do
      cards = [ Card.new('Q', 'Hearts'), Card.new('K', 'Hearts'), Card.new('A', 'Hearts') ]
      expect(Rummy::Meld.valid_run?(cards)).to eq false
    end

    it 'returns false when suits differ' do
      cards = [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Spades') ]
      expect(Rummy::Meld.valid_run?(cards)).to eq false
    end

    it "returns false when ranks aren't consecutive" do
      cards = [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('6', 'Hearts') ]
      expect(Rummy::Meld.valid_run?(cards)).to eq false
    end
  end

  describe '.valid?' do
    it 'returns true for a valid set' do
      cards = [ Card.new('7', 'Spades'), Card.new('7', 'Hearts'), Card.new('7', 'Clubs') ]
      expect(Rummy::Meld.valid?(cards)).to eq true
    end

    it 'returns true for a valid run' do
      cards = [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ]
      expect(Rummy::Meld.valid?(cards)).to eq true
    end

    it 'returns false for neither a valid set nor a valid run' do
      cards = [ Card.new('3', 'Hearts'), Card.new('4', 'Clubs'), Card.new('6', 'Spades') ]
      expect(Rummy::Meld.valid?(cards)).to eq false
    end
  end
end
