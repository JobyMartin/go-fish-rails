require 'rails_helper'

RSpec.describe Game, type: :model do
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

    it 'adds the start time' do
      game.start
      expect(game.started_at).not_to be_nil
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
