require 'rails_helper'

RSpec.describe CrazyEights::Game, type: :model do
  let(:num_players) { 5 }
  let!(:players) { Array.new(num_players) { |id| CrazyEights::Player.new(id) } }
  let!(:crazy_eights_game) { described_class.new(players) }
  let(:player) { players.first }

  describe "#dump" do
    let(:json) { described_class.dump(crazy_eights_game) }
    it "transforms players into json" do
      expect(json[:players].count).to eq num_players
    end

    it 'transforms deck into json' do
      expect(json[:deck]['cards'].count).to eq 51
    end

    it 'transforms current player index into json' do
      expect(json[:current_player_index]).to eq 0
    end
  end

  describe "#load" do
    before do
      crazy_eights_game.deal!
    end

    let!(:original_first_hand) { crazy_eights_game.players.first.hand }

    it 'preserves round-trip player state' do
      json = described_class.dump(crazy_eights_game)
      game = described_class.load(json.as_json)
      new_first_hand = game.players.first.hand

      expect(game.players).to all be_a CrazyEights::Player
      expect(new_first_hand).to eq original_first_hand
    end

    it 'preserves round-trip deck state' do
      original_top_card = crazy_eights_game.deck.cards.first
      json = described_class.dump(crazy_eights_game)
      game = described_class.load(json.as_json)
      new_top_card = game.deck.cards.first

      expect(game.deck).to be_a CrazyEights::Deck
      expect(new_top_card.rank).to eq original_top_card.rank
    end

    it 'preserves round-trip current player index state' do
      crazy_eights_game.current_player_index = 5
      original_index = crazy_eights_game.current_player_index
      json = described_class.dump(crazy_eights_game)
      game = described_class.load(json.as_json)
      new_index = game.current_player_index

      expect(new_index).to eq original_index
    end

    it 'preserves the round-trip round results state' do
      crazy_eights_game.round_results = [create_crazy_eights_round_result]
      json = described_class.dump(crazy_eights_game)
      game = described_class.load(json.as_json)
      new_round_results = game.round_results

      new_round_results.each do
        expect(it).to be_a CrazyEights::RoundResult
        expect(it.current_player).to be_a CrazyEights::Player
        expect(it.card_placed).to be_a CrazyEights::Card
      end
    end

    it 'preserves round-trip william state' do
      crazy_eights_game.william = CrazyEights::William.new([CrazyEights::Card.new])
      json = described_class.dump(crazy_eights_game)
      game = described_class.load(json.as_json)
      new_william = game.william

      expect(new_william).to be_a CrazyEights::William
      expect(new_william.cards).to all be_a CrazyEights::Card
    end
  end

  describe '#deal!' do
    let(:small_game_hand) { 5 }
    let(:large_game_hand) { 7 }
    context 'when there are more than 2 players' do
      it 'deals the players 5 cards' do
        crazy_eights_game.deal!
        dealt_players_hands = crazy_eights_game.players.map(&:hand)

        expect(dealt_players_hands.first.count).to eq small_game_hand
        dealt_players_hands.first.each do
          expect(it).to be_a CrazyEights::Card
        end
      end
    end

    context 'when there are 2 players or less' do
      let(:num_players) { 2 }
      let!(:players) { Array.new(num_players) { |id| CrazyEights::Player.new(id) } }
      let!(:crazy_eights_game) { described_class.new(players) }

      it 'deals the players 7 cards' do
        crazy_eights_game.deal!
        dealt_players_hands = crazy_eights_game.players.map(&:hand)

        expect(dealt_players_hands.first.count).to eq large_game_hand
        dealt_players_hands.first.each do
          expect(it).to be_a CrazyEights::Card
        end
      end
    end
  end

  describe '#find_player' do
    let(:user_id) { 0 }
    it 'returns the player with the name in question' do
      expect(crazy_eights_game.find_player(user_id)).to eq crazy_eights_game.players.first
    end
  end

  describe '#current_player' do
    it 'returns the current player' do
      expect(crazy_eights_game.current_player).to eq crazy_eights_game.players.first
    end
  end

  describe '#game_over?' do
    let(:num_players) { 2 }
    let!(:players) { Array.new(num_players) { |id| GoFish::Player.new(id) } }
    let!(:game) { described_class.new(players) }

    context 'when one player is out of cards' do
      before do
        game.deal!
        game.players.first.hand = []
      end

      it 'returns true' do
        expect(game.game_over?).to eq true
      end
    end

    context 'when no players are out of cards' do
      before do
        game.deal!
      end

      it 'returns false' do
        expect(game.game_over?).to eq false
      end
    end
  end

  describe '#play_turn' do
    let!(:placed_card) { CrazyEights::Card.new('2', 'Hearts') }
    it 'removes the placed card from the players hand' do
      active_player = crazy_eights_game.current_player
      active_player.hand = [placed_card]

      crazy_eights_game.play_turn(
        CrazyEights::Card.new('A', 'Hearts'),
        placed_card
      )

      expect(active_player.hand).not_to include placed_card
    end

    it 'adds the placed card to William' do
      crazy_eights_game.play_turn(
        CrazyEights::Card.new('A', 'Hearts'),
        placed_card
      )

      expect(crazy_eights_game.william.cards).to include placed_card
    end

    it 'creates a round result' do
      crazy_eights_game.play_turn(
        CrazyEights::Card.new('A', 'Hearts'),
        placed_card
      )

      message = 'Crazy Eighter placed a 2 of Hearts'
      expect(crazy_eights_game.round_results.count).to eq 1
      expect(crazy_eights_game.round_results.last.for_other_players.first).to eq message
    end

    it 'switches turns' do
      original_current_player = crazy_eights_game.current_player
      crazy_eights_game.play_turn(
        CrazyEights::Card.new('A', 'Hearts'),
        placed_card
      )

      expect(crazy_eights_game.current_player).not_to eq original_current_player
    end
  end

  describe 'valid_player_cards' do
    before do
      crazy_eights_game.william.cards << CrazyEights::Card.new('A', 'Hearts')
      crazy_eights_game.current_player.hand = [
        CrazyEights::Card.new,
        CrazyEights::Card.new('2', 'Hearts'),
        CrazyEights::Card.new('8', 'Diamonds'),
        CrazyEights::Card.new('3', 'Spades'),
        CrazyEights::Card.new('5', 'Diamonds'),
      ]
    end

    it 'returns the cards in the players hand that match the active card' do
      valid_ranks = %w(A 8)
      valid_suits = %w(Hearts)

      crazy_eights_game.valid_player_cards.each do |card|
        if valid_ranks.include?(card.rank)
          expect(valid_ranks).to include card.rank
        else
          expect(valid_suits).to include card.suit
        end
      end
    end
  end
end