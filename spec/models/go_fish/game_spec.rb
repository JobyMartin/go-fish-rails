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
end