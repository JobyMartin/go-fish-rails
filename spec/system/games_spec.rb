require 'rails_helper'

RSpec.describe 'Games', type: :system do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  it 'shows the games index' do
    visit games_path
    expect(page).to have_content 'Your Games'
    expect(page).to have_content 'All Games'
  end

  it 'shows the history' do
    visit games_history_path
    expect(page).to have_content 'Your Go Fish History'
  end

  it 'allows user to go to game creation form' do
    click_on 'New Game'
    expect(page).to have_content 'Setup Game'
  end

  context 'when a game is created' do
    it 'adds to the database' do
      expect do
        create_game
      end.to change(Game, :count).by 1
    end

    it 'sends them to the show page' do
      game_name = "Spiderman's Game"
      create_game(game_name)
      expect(page).to have_content game_name
    end
  end

  context 'when a new game is created' do
    let!(:game_name1) { "Tony Stark's Game" }
    let!(:game_name2) { "Steve Rogers' Game" }
    let!(:game) { create(:game, name: game_name1) }
    let!(:player) { create(:player, user:, game:) }
    let!(:game2) { create(:game, name: game_name2) }

    before do
      # create_game(game_name)
      visit games_path
    end

    it 'updates the games page correctly' do
      within '[data-testid="your-games"]' do
        expect(page).to have_content game_name1
      end

      within '[data-testid="all-games"]' do
        expect(page).not_to have_content game_name1
        expect(page).to have_content game_name2
      end
    end
  end

  context 'when there is an open game' do
    let!(:game) { create(:game) }

    before do
      visit games_path
      click_on 'Join'
    end

    it 'allows them to join' do
      expect(page).to have_current_path game_path(game)
    end
  end
end
