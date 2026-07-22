require 'rails_helper'

RSpec.describe RoundFeed, type: :model do
  describe '#lines' do
    it 'returns nothing for an empty feed' do
      lines = RoundFeed.new([]).lines

      expect(lines).to be_empty
    end

    it 'treats a single line as an action' do
      lines = RoundFeed.new([ 'Joby asked Sam for any 5s' ]).lines

      expect(lines.map(&:role)).to eq([ :action ])
      expect(lines.map(&:text)).to eq([ 'Joby asked Sam for any 5s' ])
    end

    it 'treats a two-line feed as action then game-response' do
      lines = RoundFeed.new([ 'Joby asked Sam for any 5s', 'Joby took 5 of Hearts from Sam' ]).lines

      expect(lines.map(&:role)).to eq([ :action, :game_response ])
    end

    it 'treats a middle line of a three-line feed as a player-response' do
      lines = RoundFeed.new([ 'action', 'reply', 'result' ]).lines

      expect(lines.map(&:role)).to eq([ :action, :player_response, :game_response ])
    end

    it 'preserves the original text at each position' do
      lines = RoundFeed.new([ 'action', 'reply', 'result' ]).lines

      expect(lines.map(&:text)).to eq([ 'action', 'reply', 'result' ])
    end
  end
end
