require 'rails_helper'

RSpec.describe GoFish::Deck, type: :model do
  let(:deck) { GoFish::Deck.new }
  let(:full_deck_size) { 52 }

  it 'should have 52 cards when created' do
    expect(deck.cards_left).to eq full_deck_size
  end

  describe '#top_card' do
    it 'should deal the top card' do
      card = deck.top_card
      expect(card).to be_a GoFish::Card
      expect(card).to respond_to(:rank)
      expect(deck.cards_left).to eq full_deck_size - 1
    end

    it 'gives a unique card each time' do
      card1 = deck.top_card
      card2 = deck.top_card
      expect(card1).not_to eq(card2)
    end
  end

  describe '#shuffle' do
    let(:example_deck) { GoFish::Deck.new }
    before { deck.shuffle }

    it 'shuffles the deck' do
      expect(deck.cards).to_not eq example_deck.cards
    end
  end

  describe '#empty?' do
    context 'when the deck is empty' do
      before { deck.cards = [] }

      it 'returns true' do
        expect(deck.empty?).to be true
      end
    end

    context 'when the deck is not empty' do
      it 'returns false' do
        expect(deck.empty?).to be false
      end
    end
  end
end

