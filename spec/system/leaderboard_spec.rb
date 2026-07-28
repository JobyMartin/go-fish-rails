require 'rails_helper'

RSpec.describe 'Leaderboard', type: :system do
  let(:champion_name) { 'ace' }
  let(:challenger_name) { 'rookie' }
  let(:champion) { create(:user, username: champion_name) }
  let(:challenger) { create(:user, username: challenger_name) }

  let(:ranked_games) { 5 }
  let(:every_game_won) { '100%' }
  let(:no_games_won) { '0%' }
  let(:hours_per_game) { FinishedGame::DURATION / 1.hour }
  let(:all_games_time) { "#{ranked_games * hours_per_game}h 0m" }

  before { sign_in(champion) }

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

      cell_in_row champion_name, LeaderboardEntry::UNRANKED
    end
  end

  context 'when a player has never joined a game' do
    before { challenger }

    it 'withholds their rank' do
      visit leaderboard_path

      cell_in_row challenger_name, LeaderboardEntry::UNRANKED
    end
  end

  context 'when sorting by a column' do
    before do
      create_list(:player, 2, :winner, :in_finished_game, user: champion)
      create_list(:player, 6, :in_finished_game, user: challenger)
    end

    def first_username = all('tbody tr td:nth-child(2)').first.text
    def first_rank = all('tbody tr td:first-child').first.text

    it 'ranks the most wins first by default' do
      visit leaderboard_path

      expect(first_username).to eq champion_name
    end

    it 'reorders by games played when that header is clicked' do
      visit leaderboard_path

      click_on 'Games played'

      expect(first_username).to eq challenger_name
    end

    it 'keeps the chosen sort in the url so it can be shared' do
      visit leaderboard_path

      click_on 'Games played'

      expect(page).to have_current_path leaderboard_path(q: { s: 'games_played desc' })
    end

    it 'reorders by win percentage when that header is clicked' do
      visit leaderboard_path

      click_on 'Win %'

      expect(first_username).to eq challenger_name
    end

    it 'keeps each board rank when sorted by another column' do
      runner_up = '2'
      visit leaderboard_path

      click_on 'Games played'

      expect(first_rank).to eq runner_up
    end
  end

  context 'when filtering' do
    before do
      create(:player, user: champion)
      create_list(:player, 3, user: challenger)
    end

    def usernames = all('tbody tr td:nth-child(2)').map(&:text)

    it 'narrows the board to a partial username match' do
      visit leaderboard_path

      fill_in 'Player name', with: 'roo'
      click_on 'Filter'

      expect(usernames).to eq [ challenger_name ]
    end

    it 'narrows the board to players with at least so many games' do
      visit leaderboard_path

      fill_in 'Fewest games', with: 2
      click_on 'Filter'

      expect(usernames).to eq [ challenger_name ]
    end

    it 'narrows the board to players with at most so many games' do
      visit leaderboard_path

      fill_in 'Most games', with: 1
      click_on 'Filter'

      expect(usernames).to eq [ champion_name ]
    end

    it 'says so when nothing matches' do
      visit leaderboard_path

      fill_in 'Player name', with: 'nobody'
      click_on 'Filter'

      expect(page).to have_content 'No players match those filters'
    end

    it 'restores the whole board when the filters are cleared' do
      visit leaderboard_path

      fill_in 'Player name', with: 'roo'
      click_on 'Filter'
      click_on 'Clear'

      expect(usernames).to match_array [ champion_name, challenger_name ]
    end

    it 'keeps the chosen sort while filtering' do
      visit leaderboard_path

      click_on 'Games played'
      fill_in 'Player name', with: 'e'
      click_on 'Filter'

      expect(usernames.first).to eq challenger_name
    end
  end

  context 'when filtering by country' do
    let(:champion) { create(:user, username: champion_name, country: 'US') }

    before { create(:user, username: challenger_name, country: 'CA') }

    it 'offers every country, not only those already on the board' do
      visit leaderboard_path

      expect(page).to have_select 'Country', options: [ 'Anywhere', *Data::Country.all.map(&:name) ]
    end

    it 'narrows the board to one country' do
      visit leaderboard_path

      select 'United States', from: 'Country'
      click_on 'Filter'

      expect(all('tbody tr td:nth-child(2)').map(&:text)).to eq [ champion_name ]
    end
  end

  context 'when there are more players than fit on one page' do
    let(:page_size) { 25 }
    let(:players_beyond_the_first_page) { 1 }

    before do
      create_list(:user, page_size).each { create(:player, :winner, user: it) }
      create(:player, user: champion)
    end

    def rows = all('tbody tr')
    def first_rank = all('tbody tr td:first-child').first.text

    it 'shows only one page of players' do
      visit leaderboard_path

      expect(rows.size).to eq page_size
    end

    it 'shows the remaining players on the next page' do
      visit leaderboard_path

      click_on 'Next'

      expect(rows.size).to eq players_beyond_the_first_page
    end

    it 'shows the board rank rather than the position on the page' do
      visit leaderboard_path

      click_on 'Next'

      expect(first_rank).to eq (page_size + 1).to_s
    end

    it 'returns to the first page when a filter is applied' do
      visit leaderboard_path(page: 2)

      fill_in 'Player name', with: 'person'
      click_on 'Filter'

      expect(rows.size).to eq page_size
    end

    it 'keeps the chosen sort while paging' do
      visit leaderboard_path

      click_on 'Games played'
      click_on 'Next'

      expect(page).to have_current_path leaderboard_path(q: { s: 'games_played desc' }, page: 2)
    end
  end

  it 'is reachable from the sidebar' do
    visit games_path

    click_on 'Leaderboard'

    expect(page).to have_current_path leaderboard_path
  end
end
