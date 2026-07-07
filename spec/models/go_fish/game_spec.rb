require 'rails_helper'

RSpec.describe GoFish::Game, type: :model do
  let(:num_players) { 5 }
  let!(:players) { Array.new(num_players, GoFish::Player.new) }
  let!(:go_fish_game) { described_class.new(players) }
  let(:player) { players.first }

  describe "#dump" do
    let(:json) { described_class.dump(go_fish_game) }
    it "transforms it into json" do # Eventually matches struct is a better test
      expect(json[:players].count).to eq num_players
    end
  end

  describe "#load" do
    let(:json) { described_class.dump(go_fish_game) }
    let(:restored) { described_class.load(json) }
    it "preserves round-trip state" do
      expect(restored.players).to all be_a GoFish::Player
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