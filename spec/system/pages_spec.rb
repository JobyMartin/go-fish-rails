require 'rails_helper'

RSpec.describe 'Pages', type: :system do
  it 'shows the game rules' do
    visit '/pages/rules'
    expect(page).to have_content 'Go Fish'
    expect(page).to have_content 'Rules'
  end
end