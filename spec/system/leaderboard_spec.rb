require 'rails_helper'

RSpec.describe 'Leaderboard', type: :system do
  let(:champion_name) { 'ace' }
  let(:challenger_name) { 'rookie' }
  let(:champion) { create(:user, username: champion_name) }
  let(:challenger) { create(:user, username: challenger_name) }

  let(:ranked_games) { User::MINIMUM_RANKED_GAMES }
  let(:every_game_won) { '100%' }
  let(:no_games_won) { '0%' }
  let(:hours_per_game) { FinishedGame::DURATION / 1.hour }
  let(:all_games_time) { "#{ranked_games * hours_per_game}h 0m" }

  before { sign_in(champion) }

  # Cell-exact, because `have_content '0%'` also matches inside '100%'.
  def cell_in_row(username, text)
    expect(find('tr', text: username)).to have_selector 'td', exact_text: text
  end

  context 'when players have finished games' do
    before do
      create_list(:player, ranked_games, :winner, :in_finished_game, user: champion)
      create_list(:player, ranked_games, :in_finished_game, user: challenger)
    end

    it 'lists every player by username' do
      visit leaderboard_path

      expect(page).to have_content champion_name
      expect(page).to have_content challenger_name
    end

    it 'shows each win percentage' do
      visit leaderboard_path

      cell_in_row champion_name, every_game_won
      cell_in_row challenger_name, no_games_won
    end

    it 'ranks the player with more wins first' do
      visit leaderboard_path

      expect(page.text.index(champion_name)).to be < page.text.index(challenger_name)
    end

    it 'shows total time played' do
      visit leaderboard_path

      cell_in_row champion_name, all_games_time
    end
  end

  context 'when a player has fewer games than the ranked minimum' do
    before { create_list(:player, ranked_games - 1, :winner, :in_finished_game, user: champion) }

    it 'withholds their win percentage' do
      visit leaderboard_path

      cell_in_row champion_name, User::UNRANKED
    end
  end

  it 'is reachable from the sidebar' do
    visit games_path

    click_on 'Leaderboard'

    expect(page).to have_current_path leaderboard_path
  end
end
