require 'rails_helper'

RSpec.describe CrazyEights::Card, type: :model do
  let(:card1) { CrazyEights::Card.new('A', 'Spades') }
  let(:card2) { CrazyEights::Card.new('K', 'Spades') }
  let(:card3) { CrazyEights::Card.new('A', 'Spades') }
  let(:card1_rank) { 'A' }
  let(:card1_suit) { 'Spades' }

  it 'has a rank and suit' do
    expect(card1.rank).to eq card1_rank
    expect(card1.suit).to eq card1_suit
  end

  it 'cards of the same rank and suit are equal' do
    expect(card1).not_to eq card2 
    expect(card1).to eq card3
  end

  it 'should allow valid ranks' do
    expect {
      CrazyEights::Card.new('15', 'Spades')
    }.to raise_error CrazyEights::Card::InvalidRank
  end

  it 'should allow valid suits' do
    expect {
      CrazyEights::Card.new('8', 'Emeralds')
    }.to raise_error CrazyEights::Card::InvalidSuit
  end

  describe '#value' do
    let(:card1) { CrazyEights::Card.new('A', 'Spades') }
    let(:card2) { CrazyEights::Card.new('5', 'Spades') }
    let(:card1_value) { 12 }
    let(:card2_value) { 3 }

    it 'returns the comparable value of the card' do
      expect(card1.value).to eq card1_value
      expect(card2.value).to eq card2_value
    end
  end

  describe '#to_s' do
    let(:card_to_string) { 'A of Spades' }
    
    it 'returns formatted card' do
      expect(card1.to_s).to eq card_to_string
    end
  end
  
  describe '#to_pathname' do
    let(:card_pathname) { 'a_spades.svg' }
    
    it 'returns formatted card' do
      expect(card1.to_pathname).to eq card_pathname
    end
  end

  describe '#objectify' do
    it 'turns a card string into an object' do
      card_string = '6 of Diamonds'
      objectified_card = described_class.objectify(card_string)
      expect(objectified_card).to be_a CrazyEights::Card
      expect(objectified_card.rank).to eq '6'
      expect(objectified_card.suit).to eq 'Diamonds'
    end
  end
end