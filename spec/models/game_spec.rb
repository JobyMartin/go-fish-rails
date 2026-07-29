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

  describe '.playable_types' do
    it 'lists exactly the playable subclasses with labels' do
      expect(Game.playable_types).to eq(
        'GoFishGame' => 'Go Fish', 'CrazyEightsGame' => 'Crazy Eights', 'RummyGame' => 'Rummy'
      )
    end
  end

  describe '.playable_class' do
    it 'returns the subclass for a registered type' do
      expect(Game.playable_class('CrazyEightsGame')).to eq CrazyEightsGame
    end

    it 'returns nil for an unregistered type' do
      expect(Game.playable_class('EvilGame')).to be_nil
    end
  end

  describe '#build_game' do
    it 'does not silently coerce an unknown type into Crazy Eights' do
      stub_const('EvilGame', Class.new(Game))
      game = EvilGame.new(name: 'Evil')
      create(:player, user:, game:)
      expect { game.send(:build_game) }.to raise_error(NoMethodError)
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
        expect(player.hand.count).to eq 7
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
        game.play_turn(player: inquired_player_id, rank: bad_inquired_rank)
        expect(game.game_state.current_player.hand_size).to eq 7
        expect(game.game_state.players.first.hand_size).to eq 1
      end
    end

    context 'when the current player has cards' do
      before do
        game.start
        inquired_player_id
      end

      it 'plays a turn' do
        game.play_turn(player: inquired_player_id, rank: good_inquired_rank)
        expect(game.game_state.players.first.hand_size).to eq 8
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

  describe '#duration' do
    it 'is the span between starting and ending' do
      player = create(:player, :in_finished_game)
      expect(player.game.reload.duration).to eq FinishedGame::DURATION
    end

    it 'is nil while the game is unfinished' do
      expect(create(:game, :in_progress).duration).to be_nil
    end
  end

  describe '#finish!' do
    let(:game) { create(:game) }
    let(:player_count) { 2 }
    let(:expected_winners) { 1 }
    let!(:players) { create_list(:player, player_count, game: game) }

    before do
      game.start
      game.finish!
    end

    it 'records the end time' do
      expect(game.reload.ended_at).not_to be_nil
    end

    it 'marks the winning player' do
      winning_user_id = game.game_state.winner.id
      expect(game.players.find_by(user_id: winning_user_id)).to be_winner
    end

    it 'leaves the other players unmarked' do
      expect(game.players.count(&:winner)).to eq expected_winners
    end

    it 'does not overwrite an already finished game' do
      expect { game.finish! }.not_to change { game.reload.ended_at }
    end
  end
end
