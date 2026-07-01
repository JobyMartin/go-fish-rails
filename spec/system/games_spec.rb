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
    expect(page).to have_content 'Create a game'
  end

  fcontext 'when a game is created' do
    let(:game) { create :game }
    it 'redirects and adds to the database' do
      expect do
        visit new_game_path
        fill_in 'Name', with: game.name
        select 'Go Fish', from: 'Type'
        click_on 'Create Game'
      end.to change(Game, :count).by 1
    end
  end
end
