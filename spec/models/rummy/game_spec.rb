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

    it 'seeds the table with demo melds' do
      game.deal!

      expect(game.melds).not_to be_empty
      expect(game.melds).to all(be_a(Rummy::Meld))
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
  end
end
