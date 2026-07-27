require 'rails_helper'

RSpec.describe User, type: :model do
  let(:valid_password) { 'grilledcheese' }
  let(:invalid_password) { 'cheeseburger' }

  context 'when bad email is provided' do
    let(:user) { build(:user, email_address: 'toast') }
    it 'is invalid' do
      expect(user).to be_invalid
    end
  end

  context 'when good email is provided' do
    let(:user) { build(:user, email_address: 'toast@grilledcheese.com', password: valid_password, confirm_password: valid_password) }
    it 'is valid' do
      expect(user).to be_valid
    end
  end

  context 'when bad password is provided' do
    let(:user) { build(:user, password: 'toast') }
    it 'is valid' do
      expect(user).to be_invalid
    end
  end

  context 'when good password is provided' do
    let(:user) { build(:user, password: valid_password, confirm_password: valid_password) }
    it 'is valid' do
      expect(user).to be_valid
    end
  end

  context 'when confirmation password does not match password' do
    let(:user) { build(:user, password: valid_password, confirm_password: invalid_password) }
    it 'is invalid' do
      expect(user).to be_invalid
    end
  end

  context 'when confirmation password matches password' do
    let(:user) { build(:user, password: valid_password, confirm_password: valid_password) }
    it 'is valid' do
      expect(user).to be_valid
    end
  end

  context 'when no username is provided' do
    let(:user) { build(:user, username: nil) }
    it 'is invalid' do
      expect(user).to be_invalid
    end
  end

  context 'when the username is already taken' do
    let(:taken_username) { 'ace' }
    before { create(:user, username: taken_username) }
    let(:user) { build(:user, username: taken_username.upcase) }

    it 'is invalid' do
      expect(user).to be_invalid
    end
  end

  describe 'leaderboard statistics' do
    let(:user) { create(:user) }
    let(:ranked_games) { User::MINIMUM_RANKED_GAMES }

    describe '#games_played' do
      let(:games_joined) { 3 }

      it 'counts every game joined' do
        create_list(:player, games_joined, user: user)
        expect(user.games_played).to eq games_joined
      end
    end

    describe '#games_won' do
      let(:wins) { 2 }
      let(:losses) { 1 }

      before do
        create_list(:player, wins, :winner, user: user)
        create_list(:player, losses, user: user)
      end

      it 'counts only the wins' do
        expect(user.games_won).to eq wins
      end
    end

    describe '#win_percentage' do
      it 'is nil below the ranked minimum' do
        create_list(:player, ranked_games - 1, :winner, user: user)
        expect(user.win_percentage).to be_nil
      end

      it 'is wins over games played once ranked' do
        half_of_the_games = ranked_games
        create_list(:player, half_of_the_games, :winner, user: user)
        create_list(:player, half_of_the_games, user: user)
        expect(user.win_percentage).to eq 50
      end

      it 'rounds a repeating fraction to a whole number' do
        one_win_in_six = 17
        create(:player, :winner, user: user)
        create_list(:player, 5, user: user)
        expect(user.win_percentage).to eq one_win_in_six
      end
    end

    describe '#time_played' do
      let(:finished_games) { 2 }

      it 'sums the duration of finished games' do
        create_list(:player, finished_games, :in_finished_game, user: user)
        expect(user.time_played).to eq finished_games * FinishedGame::DURATION
      end

      it 'ignores games that never finished' do
        create(:player, user: user)
        expect(user.time_played).to be_zero
      end
    end
  end
end
