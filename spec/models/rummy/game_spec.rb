require 'rails_helper'

RSpec.describe Rummy::Game, type: :model do
  let(:num_players) { 3 }
  let!(:players) { Array.new(num_players) { |id| Rummy::Player.new(id) } }
  let!(:game) { described_class.new(players) }

  describe '#deal!' do
    it 'deals every player a hand' do
      game.deal!

      expect(game.players).to all(satisfy { it.hand.any? })
    end

    it 'deals every player the same number of cards' do
      game.deal!

      expect(game.players.map { it.hand.count }.uniq).to eq [ 7 ]
    end

    it 'deals 10 cards per player in a 2-player game' do
      two_player_game = described_class.new(Array.new(2) { |id| Rummy::Player.new(id) })

      two_player_game.deal!

      expect(two_player_game.players.map { it.hand.count }.uniq).to eq [ 10 ]
    end

    it 'deals 7 cards per player in a 3-4 player game' do
      four_player_game = described_class.new(Array.new(4) { |id| Rummy::Player.new(id) })

      four_player_game.deal!

      expect(four_player_game.players.map { it.hand.count }.uniq).to eq [ 7 ]
    end

    it 'deals 6 cards per player in a 5-6 player game' do
      six_player_game = described_class.new(Array.new(6) { |id| Rummy::Player.new(id) })

      six_player_game.deal!

      expect(six_player_game.players.map { it.hand.count }.uniq).to eq [ 6 ]
    end

    it 'starts with no melds on the table' do
      game.deal!

      expect(game.melds).to be_empty
    end

    it 'seeds a discard pile with a top card' do
      game.deal!

      expect(game.active_card).to be_a(Card)
    end
  end

  describe '#find_player' do
    it 'returns the player matching the given user id' do
      expect(game.find_player(0)).to eq players.first
    end
  end

  describe '#current_player' do
    it 'returns the player at current_player_index' do
      expect(game.current_player).to eq players.first
    end
  end

  describe '#game_over?' do
    before { game.deal! }

    it 'returns false when no player has emptied their hand' do
      expect(game.game_over?).to eq false
    end

    it 'returns true when a player has emptied their hand' do
      players.first.hand = []

      expect(game.game_over?).to eq true
    end
  end

  describe '#winner' do
    before { game.deal! }

    it 'returns nil when no player has emptied their hand' do
      expect(game.winner).to be_nil
    end

    it 'returns the player who emptied their hand' do
      players.first.hand = []

      expect(game.winner).to eq players.first
    end
  end

  describe '#sort_hand' do
    it "sorts the given player's hand" do
      players.first.hand = [ Card.new('K', 'Clubs'), Card.new('A', 'Diamonds') ]

      game.sort_hand(players.first.id)

      expect(players.first.hand).to eq [ Card.new('A', 'Diamonds'), Card.new('K', 'Clubs') ]
    end
  end

  describe '#smart_sort_hand' do
    it "smart-sorts the given player's hand" do
      players.first.hand = [ Card.new('2', 'Hearts'), Card.new('5', 'Clubs'), Card.new('5', 'Diamonds') ]

      game.smart_sort_hand(players.first.id)

      expect(players.first.hand).to eq [
        Card.new('5', 'Diamonds'), Card.new('5', 'Clubs'), Card.new('2', 'Hearts')
      ]
    end
  end

  describe '#draw' do
    before { game.deal! }

    it "adds the deck's top card to the current player's hand when source is deck" do
      top_card = game.deck.cards.first

      game.draw('deck')

      expect(game.current_player.hand).to include top_card
    end

    it "adds the discard pile's top card to the current player's hand when source is discard" do
      top_card = game.discard_pile.last

      game.draw('discard')

      expect(game.current_player.hand).to include top_card
    end

    it 'marks drawn_this_turn as true' do
      game.draw('deck')

      expect(game.drawn_this_turn).to eq true
    end

    it 'records a round result when taking from the discard pile' do
      top_card = game.discard_pile.last

      game.draw('discard')

      expect(game.round_results.last.card_taken).to eq top_card
    end

    it 'does not record a round result when drawing from the deck' do
      game.draw('deck')

      expect(game.round_results).to be_empty
    end

    it 'remembers the card taken from the discard pile' do
      top_card = game.discard_pile.last

      game.draw('discard')

      expect(game.taken_from_discard).to eq top_card
    end

    it 'does not remember a card taken from the deck' do
      game.draw('deck')

      expect(game.taken_from_discard).to be_nil
    end
  end

  describe '#meld' do
    let(:run_tokens) { [ '3 Hearts', '4 Hearts', '5 Hearts' ] }

    before do
      game.deal!
      game.current_player.hand = [
        Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts'), Card.new('K', 'Spades')
      ]
    end

    it "adds a valid run from the current player's hand as a new table meld" do
      game.meld(run_tokens)

      expect(game.melds.last.cards).to eq [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ]
    end

    it "removes the melded cards from the current player's hand" do
      current_hand_size = game.current_player.hand.count

      game.meld(run_tokens)

      expect(game.current_player.hand.count).to eq current_hand_size - 3
    end

    it 'raises and leaves the hand and table untouched on an invalid meld' do
      before_hand = game.current_player.hand.dup

      expect { game.meld([ '3 Hearts', '4 Hearts' ]) }.to raise_error(Rummy::InvalidMove, /valid set or run/)
      expect(game.current_player.hand).to eq before_hand
      expect(game.melds).to be_empty
    end

    it 'ignores blank tokens from unchecked checkbox hidden fields' do
      game.meld(run_tokens + [ '', '' ])

      expect(game.melds.last.cards).to eq [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ]
    end

    it 'removes only one instance of a card when a duplicate value remains in hand' do
      game.current_player.hand << Card.new('5', 'Hearts')

      game.meld(run_tokens)

      expect(game.current_player.hand).to include Card.new('5', 'Hearts')
    end

    it 'marks the current player as having melded' do
      game.meld(run_tokens)

      expect(game.current_player.melded?).to eq true
    end

    it 'does not mark the current player as having melded on an invalid meld' do
      expect { game.meld([ '3 Hearts', '4 Hearts' ]) }.to raise_error(Rummy::InvalidMove)
      expect(game.current_player.melded?).to eq false
    end
  end

  describe '#layoff' do
    before do
      game.melds = [ Rummy::Meld.new([ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ]) ]
      game.current_player.hand = [ Card.new('6', 'Hearts') ]
    end

    it 'raises and does not lay off before the current player has melded' do
      expect { game.layoff(0, '6 Hearts') }.to raise_error(Rummy::InvalidMove, /lay down a meld/)
      expect(game.melds.first.cards.count).to eq 3
      expect(game.current_player.hand).to eq [ Card.new('6', 'Hearts') ]
    end

    context 'when the current player has melded' do
      before { game.current_player.mark_melded! }

      it 'adds a valid card from hand onto the given table meld' do
        game.layoff(0, '6 Hearts')

        expect(game.melds.first.cards).to eq [
          Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts'), Card.new('6', 'Hearts')
        ]
      end

      it 'removes the laid off card from hand' do
        game.layoff(0, '6 Hearts')

        expect(game.current_player.hand).to be_empty
      end

      it "raises when the card wouldn't extend a valid set/run" do
        game.current_player.hand = [ Card.new('2', 'Clubs') ]

        expect { game.layoff(0, '2 Clubs') }.to raise_error(Rummy::InvalidMove, /can't be added/)
        expect(game.melds.first.cards.count).to eq 3
        expect(game.current_player.hand).to eq [ Card.new('2', 'Clubs') ]
      end
    end
  end

  describe '#discard' do
    before do
      game.current_player.hand = [ Card.new('7', 'Spades'), Card.new('8', 'Spades') ]
      game.drawn_this_turn = true
    end

    it "moves the card from the current player's hand to the discard pile" do
      discarding_player = game.current_player

      game.discard('7 Spades')

      expect(game.discard_pile.last).to eq Card.new('7', 'Spades')
      expect(discarding_player.hand).to eq [ Card.new('8', 'Spades') ]
    end

    it 'records a round result describing the discard' do
      game.discard('7 Spades')

      expect(game.round_results.last.card_discarded).to eq Card.new('7', 'Spades')
    end

    it 'does not mark the round result as going out when cards remain' do
      game.discard('7 Spades')

      expect(game.round_results.last.going_out).to eq false
    end

    it 'marks the round result as going out when the discard empties the hand' do
      game.current_player.hand = [ Card.new('7', 'Spades') ]

      game.discard('7 Spades')

      expect(game.round_results.last.going_out).to eq true
    end

    it 'resets drawn_this_turn to false' do
      game.discard('7 Spades')

      expect(game.drawn_this_turn).to eq false
    end

    it 'advances to the next player' do
      before_index = game.current_player_index

      game.discard('7 Spades')

      expect(game.current_player_index).not_to eq before_index
    end

    it "does not advance turns when the discard empties the player's hand" do
      game.current_player.hand = [ Card.new('7', 'Spades') ]
      before_index = game.current_player_index

      game.discard('7 Spades')

      expect(game.current_player_index).to eq before_index
    end

    context 'when discarding the card just taken from the discard pile' do
      before do
        game.discard_pile = [ Card.new('7', 'Spades') ]
        game.draw('discard')
      end

      it 'raises and keeps the card in hand' do
        expect { game.discard('7 Spades') }.to raise_error(Rummy::InvalidMove, /just took/)
        expect(game.current_player.hand).to include Card.new('7', 'Spades')
      end

      it 'does not add the card back to the discard pile' do
        expect { game.discard('7 Spades') }.to raise_error(Rummy::InvalidMove)
        expect(game.discard_pile).to be_empty
      end

      it 'does not advance to the next player' do
        before_index = game.current_player_index

        expect { game.discard('7 Spades') }.to raise_error(Rummy::InvalidMove)
        expect(game.current_player_index).to eq before_index
      end

      it 'still allows discarding a different card' do
        game.discard('8 Spades')

        expect(game.discard_pile.last).to eq Card.new('8', 'Spades')
      end
    end
  end

  describe '#active_card' do
    before { game.deal! }

    it 'returns the top of the discard pile' do
      expect(game.active_card).to eq game.discard_pile.last
    end
  end

  describe 'as_json / from_json' do
    before { game.deal! }

    let(:loaded) { described_class.load(described_class.dump(game).as_json) }

    it 'preserves player hands' do
      expect(loaded.players.map(&:hand)).to eq game.players.map(&:hand)
    end

    it 'preserves the deck' do
      expect(loaded.deck.cards.map(&:rank)).to eq game.deck.cards.map(&:rank)
    end

    it 'preserves the melds' do
      expect(loaded.melds.map(&:cards)).to eq game.melds.map(&:cards)
    end

    it 'preserves the discard pile' do
      expect(loaded.discard_pile).to eq game.discard_pile
    end

    it 'preserves round results' do
      expect(loaded.round_results).to eq game.round_results
    end

    it 'preserves the current player index' do
      expect(loaded.current_player_index).to eq game.current_player_index
    end

    it 'preserves whether a card has been drawn this turn' do
      expect(loaded.drawn_this_turn).to eq game.drawn_this_turn
    end

    it 'preserves the card taken from the discard pile' do
      game.draw('discard')
      loaded_with_discard_draw = described_class.load(described_class.dump(game).as_json)

      expect(loaded_with_discard_draw.taken_from_discard).to eq game.taken_from_discard
    end
  end
end
