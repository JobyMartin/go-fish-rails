require 'rails_helper'

RSpec.describe 'Games', type: :system do
  it 'shows the games index' do
    visit '/games'
    expect(page).to have_content 'Your Games'
    expect(page).to have_content 'All Games'
  end
end