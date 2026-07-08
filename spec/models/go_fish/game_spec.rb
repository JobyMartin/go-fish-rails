require 'rails_helper'

RSpec.describe GoFish::Game, type: :model do
  let(:num_players) { 5 }
  let!(:players) { Array.new(num_players) { GoFish::Player.new } }
  let!(:go_fish_game) { described_class.new(players) }
  let(:player) { players.first }

  describe "#dump" do
    let(:json) { described_class.dump(go_fish_game) }
    it "transforms players into json" do
      expect(json[:players].count).to eq num_players
    end

    it 'transforms deck into json' do
      expect(json[:deck]['cards'].count).to eq 52
    end

    it 'transforms current player index into json' do
      expect(json[:current_player_index]).to eq 0
    end
  end

  describe "#load" do
    let!(:original_first_hand) { go_fish_game.players.first.hand }
    let!(:original_first_books) { go_fish_game.players.first.books }
    
    before do
      go_fish_game.deal!
    end
    
    it 'preserves round-trip player state' do
      json = described_class.dump(go_fish_game)
      game = described_class.load(json.as_json)
      new_first_hand = game.players.first.hand
      new_first_books = game.players.first.books

      expect(game.players).to all be_a GoFish::Player
      expect(new_first_hand).to eq original_first_hand
      expect(new_first_books).to eq original_first_books
    end

    it 'preserves round-trip deck state' do
      original_top_card = go_fish_game.deck.cards.first
      json = described_class.dump(go_fish_game)
      game = described_class.load(json.as_json)
      new_top_card = game.deck.cards.first

      expect(game.deck).to be_a GoFish::Deck
      expect(new_top_card.rank).to eq original_top_card.rank
    end

    it 'preserves round-trip current player index state' do
      go_fish_game.current_player_index = 5
      original_index = go_fish_game.current_player_index
      json = described_class.dump(go_fish_game)
      game = described_class.load(json.as_json)
      new_index = game.current_player_index

      expect(new_index).to eq original_index
    end

    it 'preserves the round-trip round results state' do
      go_fish_game.round_results = 'mock state'
      original_round_results = go_fish_game.round_results
      json = described_class.dump(go_fish_game)
      game = described_class.load(json.as_json)
      new_round_results = game.round_results

      expect(new_round_results).to eq original_round_results
    end
  end

  describe '#deal!' do
    it 'deals the players cards' do
      go_fish_game.deal!
      dealt_players_hands = go_fish_game.players.map(&:hand)

      expect(dealt_players_hands.first.count).to eq 5
      dealt_players_hands.first.each do
        expect(it).to be_a GoFish::Card
      end
    end
  end

  describe '#current_player' do
    it 'returns the current player' do
      expect(go_fish_game.current_player).to eq go_fish_game.players.first
    end
  end

  describe '#find_player' do
    let(:user_id) { 0 }
    it 'returns the player with the name in question' do
      expect(go_fish_game.find_player(user_id)).to eq go_fish_game.players.first
    end
  end
end