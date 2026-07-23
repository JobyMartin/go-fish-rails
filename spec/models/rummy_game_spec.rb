require 'rails_helper'

RSpec.describe RummyGame, type: :model do
  describe '#build_game' do
    it 'builds a Rummy::Game domain object with a player per user' do
      game = create(:game, type: 'RummyGame')
      create(:player, game:)

      game.start

      expect(game.game_state).to be_a Rummy::Game
      expect(game.game_state.players.count).to eq game.players.count
    end
  end

  describe '#play_turn' do
    let(:game) { create(:game, type: 'RummyGame') }

    before do
      create(:player, game:)
      game.start
    end

    it 'dispatches a draw move to the domain game' do
      before_hand_size = game.game_state.current_player.hand.count

      game.play_turn(move: 'draw', source: 'deck')

      expect(game.game_state.current_player.hand.count).to eq before_hand_size + 1
    end

    it 'dispatches a meld move to the domain game' do
      game.game_state.current_player.hand = [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ]

      game.play_turn(move: 'meld', card_ids: [ '3 Hearts', '4 Hearts', '5 Hearts' ])

      expect(game.game_state.melds.last.cards).to eq [
        Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts')
      ]
    end

    it 'dispatches a layoff move to the domain game' do
      game.game_state.melds = [
        Rummy::Meld.new([ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ])
      ]
      game.game_state.current_player.hand = [ Card.new('6', 'Hearts') ]

      game.play_turn(move: 'layoff', meld_id: 0, card_id: '6 Hearts')

      expect(game.game_state.melds.first.cards.count).to eq 4
    end

    it 'dispatches a discard move to the domain game' do
      game.game_state.current_player.hand = [ Card.new('7', 'Spades') ]

      game.play_turn(move: 'discard', card_id: '7 Spades')

      expect(game.game_state.discard_pile.last).to eq Card.new('7', 'Spades')
    end
  end

  describe 'shared contract' do
    let(:game) { create(:game, type: 'RummyGame') }

    before do
      create(:player, game:)
      create(:player, game:)
      game.start
      game.save!
    end

    it_behaves_like 'a persisted card game'
  end
end
