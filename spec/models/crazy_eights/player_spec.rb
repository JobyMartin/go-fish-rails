require 'rails_helper'

RSpec.describe CrazyEights::Player, type: :model do
  let(:player) { CrazyEights::Player.new('Joby') }
  let(:card1) { CrazyEights::Card.new('A', 'Spades') }
  let(:card2) { CrazyEights::Card.new('K', 'Spades') }
  let(:card3) { CrazyEights::Card.new('A', 'Hearts') }
  let(:card4) { CrazyEights::Card.new('A', 'Diamonds') }
  let(:card5) { CrazyEights::Card.new('A', 'Clubs') }
  let(:card6) { CrazyEights::Card.new('K', 'Hearts') }
  let(:card7) { CrazyEights::Card.new('K', 'Diamonds') }
  let(:card8) { CrazyEights::Card.new('K', 'Clubs') }

  describe '#add_cards' do
    it 'adds cards to the bottom of the deck' do
      player.add_cards([card1, card2])
      expect(player.hand).to eq [card1, card2]
    end

    xcontext 'when the fourth card is added' do
      before do
        player.add_cards([card6, card7, card8, card2])
      end

      it 'makes a book' do
        post_book_creation_count = 1
        expect(player.hand).to be_empty
        expect(player.book_size).to eq post_book_creation_count
      end
    end

    xcontext 'when no cards are given' do
      it 'does not make a book' do
        book_size = player.book_size
        player.add_cards([])
        expect(player.book_size).to eq book_size
      end
    end
  end
end