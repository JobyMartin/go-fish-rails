require 'rails_helper'

RSpec.describe GoFish::Game, type: :model do
  let(:num_players) { 5 }
  let!(:players) { Array.new(num_players, GoFish::Player.new) }
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
  end

  describe "#load" do
    let(:json) { described_class.dump(go_fish_game) }
    let(:restored) { described_class.load(json) }
    it 'preserves round-trip player state' do
      expect(restored.players).to all be_a GoFish::Player
    end

    it 'preserves round-trip deck state' do
      original_top_card = go_fish_game.deck.cards.first
      json = described_class.dump(go_fish_game)
      game = described_class.load(json)
      new_top_card = game.deck.cards.first

      expect(game.deck).to be_a GoFish::Deck
      expect(new_top_card.rank).to eq original_top_card.rank
    end
  end

  describe '#deal!' do
    it 'deals the players cards' do
      go_fish_game.deal!
      dealt_players_hands = go_fish_game.players.map(&:hand)

      dealt_players_hands.first.each do
        expect(it).to be_a GoFish::Card
      end
    end
  end
end