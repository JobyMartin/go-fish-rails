require 'rails_helper'

RSpec.describe LeaderboardEntry do
  let(:ranked_games) { User::MINIMUM_RANKED_GAMES }

  def entry_for(username) = described_class.find_by(username:)

  describe 'the view' do
    let(:username) { 'solo' }
    let(:user) { create(:user, username:) }

    it 'counts every game joined' do
      games_joined = 3
      create_list(:player, games_joined, user:)

      expect(entry_for(username).games_played).to eq games_joined
    end

    it 'counts only the wins' do
      wins = 2
      losses = 1
      create_list(:player, wins, :winner, user:)
      create_list(:player, losses, user:)

      expect(entry_for(username).games_won).to eq wins
    end

    it 'sums the duration of finished games' do
      finished_games = 2
      create_list(:player, finished_games, :in_finished_game, user:)

      expect(entry_for(username).time_played).to eq finished_games * FinishedGame::DURATION
    end

    it 'ignores games that never finished' do
      create(:player, user:)

      expect(entry_for(username).time_played).to be_zero
    end

    it 'includes a user who has never joined a game' do
      user

      expect(entry_for(username).games_played).to be_zero
    end

    it 'is readonly' do
      user

      expect { entry_for(username).update!(username: 'renamed') }
        .to raise_error ActiveRecord::ReadOnlyRecord
    end
  end

  describe '#win_percentage' do
    let(:username) { 'solo' }
    let(:user) { create(:user, username:) }

    it 'is nil below the ranked minimum' do
      below_minimum = ranked_games - 1
      create_list(:player, below_minimum, :winner, user:)

      expect(entry_for(username).win_percentage).to be_nil
    end

    it 'is wins over games played once ranked' do
      even_split = 50
      create_list(:player, ranked_games, :winner, user:)
      create_list(:player, ranked_games, user:)

      expect(entry_for(username).win_percentage).to eq even_split
    end

    it 'rounds a repeating fraction to a whole number' do
      losses = 5
      one_win_in_six = 17
      create(:player, :winner, user:)
      create_list(:player, losses, user:)

      expect(entry_for(username).win_percentage).to eq one_win_in_six
    end
  end

  describe '.ranked' do
    let(:champion_name) { 'ace' }
    let(:challenger_name) { 'rookie' }
    let(:champion) { create(:user, username: champion_name) }
    let(:challenger) { create(:user, username: challenger_name) }
    let(:champion_first) { [ champion_name, challenger_name ] }

    def top_two = described_class.ranked.map(&:username).first(2)

    it 'ranks more wins first' do
      fewer_wins = 2
      more_wins = 3
      create_list(:player, fewer_wins, :winner, user: challenger)
      create_list(:player, more_wins, :winner, user: champion)

      expect(top_two).to eq champion_first
    end

    it 'breaks a tie on wins by fewer games played' do
      tied_wins = 2
      extra_losses = 4
      create_list(:player, tied_wins, :winner, user: champion)
      create_list(:player, tied_wins, :winner, user: challenger)
      create_list(:player, extra_losses, user: challenger)

      expect(top_two).to eq champion_first
    end

    it 'breaks a full tie by username so the order is stable' do
      create(:player, :winner, user: challenger)
      create(:player, :winner, user: champion)

      expect(top_two).to eq champion_first
    end
  end
end
