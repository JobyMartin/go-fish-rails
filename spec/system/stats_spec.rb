require 'rails_helper'

RSpec.describe 'Stats', type: :system do
  let(:user) { create(:user) }
  let(:game1) { create(:game) }
  let(:game2) { create(:game) }

  before do
    sign_in(user)
  end

  context 'when the user views the stats page' do
    let!(:player) { create(:player, user: user, game: game1) }
    let!(:player1) { create(:player, user: user, game: game2) }

    it 'displays their total games' do
      num_of_games = 2
      visit stats_path
      expect(page).to have_content num_of_games
    end

    it 'displays theit total games won' do
      player.winner = true
      player.save
      num_of_wins = 1
      visit stats_path
      expect(page).to have_content num_of_wins
    end

    it 'displays theit win percentage' do
      player.winner = true
      player.save
      win_percentage = '50%'
      visit stats_path
      expect(page).to have_content win_percentage
    end
  end
end
