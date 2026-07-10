require 'rails_helper'

RSpec.describe Game, type: :model do
  let(:user) { create(:user) }
  let(:user2) { create(:user) }

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
      expect(game.game_state).not_to be nil
    end

    it 'creates a game with players for each user' do
      game.start
      expect(game.game_state.players.count).to eq game.players.count
    end

    it 'deals the cards' do
      game.start
      game.game_state.players.each do |player|
        expect(player.hand.count).to eq 5
      end
    end

    it 'saves it to the database' do
      game.start
      expect(game.reload.game_state).to be_present
    end
  end

  describe '#play_go_fish' do
    let!(:game) { create(:game) }
    let!(:player) { create(:player, user:, game:) }
    let!(:player2) { create(:player, user: user2, game:) }
    let(:inquired_player_id) { game.game_state.players.last.id }
    let(:good_inquired_rank) { 'A' }
    let(:bad_inquired_rank) { nil }

    context 'when the current player has no cards' do
      before do
        game.start
        inquired_player_id
        game.game_state.current_player.hand = []
      end
      it 'fishes and skips' do
        game.play_turn(inquired_player_id, bad_inquired_rank)
        expect(game.game_state.current_player.hand_size).to eq 5
        expect(game.game_state.players.first.hand_size).to eq 1
      end
    end

    context 'when the current player has cards' do
      before do
        game.start
        inquired_player_id
      end

      it 'plays a turn' do
        game.play_turn(inquired_player_id, good_inquired_rank)
        expect(game.game_state.players.first.hand_size).to eq 6
      end
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
