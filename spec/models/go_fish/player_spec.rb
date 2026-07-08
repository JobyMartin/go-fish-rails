require 'rails_helper'

RSpec.describe GoFish::Player, type: :model do
  let(:player) { GoFish::Player.new('Joby') }
  let(:card1) { GoFish::Card.new('A', 'Spades') }
  let(:card2) { GoFish::Card.new('K', 'Spades') }
  let(:card3) { GoFish::Card.new('A', 'Hearts') }
  let(:card4) { GoFish::Card.new('A', 'Diamonds') }
  let(:card5) { GoFish::Card.new('A', 'Clubs') }
  let(:card6) { GoFish::Card.new('K', 'Hearts') }
  let(:card7) { GoFish::Card.new('K', 'Diamonds') }
  let(:card8) { GoFish::Card.new('K', 'Clubs') }

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

  describe '#get_cards_by_rank' do
    let(:rank_in_question) { 'A' }

    context 'the players hand contains the rank in question' do

      before do
        player.add_cards([card1, card2, card3])
      end

      it 'deletes the card with the common rank' do
        player.get_cards_by_rank(rank_in_question)
        expect(player.hand).not_to include card1, card3
      end

      it 'returns all of the cards with the common rank' do
        expect(player.get_cards_by_rank(rank_in_question)).to match_array [card1, card3]
      end

      it 'does not return other cards' do
        player.get_cards_by_rank(rank_in_question)
        expect(player.hand).to include card2
      end
    end

    context 'the players hand does not contain the rank in question' do
      before do
        player.add_cards([card2])
      end

      it 'returns and empty array' do
        expect(player.get_cards_by_rank(rank_in_question)).to be_empty
      end
    end
  end

  describe '#hand_size' do
    let(:empty_hand_size) { 0 }

    context 'when the player has no cards' do
      it 'returns a value of 0' do
        expect(player.hand_size).to eq empty_hand_size
      end
    end

    context 'when the player has many cards' do
      it 'returns the quantity of cards' do
        player.hand.push(card1, card2)
        expect(player.hand_size).to eq empty_hand_size + 2
      end
    end
  end

  xdescribe '#formatted_hand' do
    it 'displays players hand' do
      player.add_cards([card1, card2])
      expect(player.formatted_hand).to eq "- A of Spades\n- K of Spades\n"
    end
  end

  xdescribe '#make_book_if_possible' do
    let(:rank) { 'A' }

    context 'when the player has four matching cards' do
      before do
        player.add_cards([card1, card3, card4, card5])
        player.make_book_if_possible(rank)
      end

      it 'makes a book of four cards' do
        expect(player.hand).to be_empty
        expect(player.books.first).to be_a GoFish::Book
      end
    end

    context 'when the player does not have four matching cards' do
      before do
        player.make_book_if_possible(rank)
      end
      
      it 'makes a book of four cards' do
        expect(player.books).to be_empty
      end
    end
  end

  xdescribe '#formatted books' do
    it 'displays players books' do
      player.books << GoFish::Book.new([card1, card5, card3, card4])
      expect(player.formatted_books).to eq "Books:\n- A\n"
    end
  end

  xdescribe '#highest_book_value' do
    before do
      player.books << GoFish::Book.new([card1, card5, card3, card4])
      player.books << GoFish::Book.new([card2, card6, card7, card8])
    end
    it 'returns the highest book value of the player' do
      expect(player.highest_book_value).to eq 12
    end
  end

  describe '#book_size' do
    let(:book_size) { 2 }

    before do
      player.books << GoFish::Book.new([card1, card5, card3, card4])
      player.books << GoFish::Book.new([card2, card6, card7, card8])
    end

    it 'returns the size of the players books array' do
      expect(player.book_size).to eq book_size
    end
  end
end