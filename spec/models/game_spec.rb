require 'rails_helper'

RSpec.describe Game, type: :model do
  let(:user) { create(:user) }

  describe '#status' do
    let!(:game) { create :game }

    context 'when the game has not started' do
      it 'returns waiting' do
        expect(game.status).to eq 'Waiting...'
      end
    end

    context 'when the game has started and not ended' do
      before do
        game.started_at = Time.now
      end

      it 'returns in progress' do
        expect(game.status).to eq 'In progress'
      end
    end

    context 'when the game has ended' do
      before do
        game.started_at = Time.now
        game.ended_at = Time.now
      end

      it 'returns in progress' do
        expect(game.status).to eq 'Finished'
      end
    end
  end

  describe '#start' do
  let!(:game) { create(:game) }
  let!(:player) { create(:player, user:, game:) }

    it 'adds the start time' do
      game.start
      expect(game.started_at).not_to be_nil
    end

    it 'creates a game' do
      game.start
      expect(game.go_fish).not_to be nil
    end

    it 'creates a game with players for each user' do
      game.start
      expect(game.go_fish.players.count).to eq game.players.count
    end

    it 'deals the cards' do
      game.start
      game.go_fish.players.each do |player|
        expect(player.hand.count).to eq 5
      end
    end

    it 'saves it to the database' do
      game.start
      expect(game.reload.go_fish).to be_present
    end
  end

  describe '#end' do
    let!(:game) { create(:game) }

    it 'adds the end time' do
      game.end
      expect(game.ended_at).not_to be_nil
    end
  end
end
