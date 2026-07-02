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
end
