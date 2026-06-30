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
end
