require 'rails_helper'

RSpec.describe 'Pages', type: :system do
  it 'shows the game rules' do
    visit pages_rules_path
    expect(page).to have_content 'Go Fish'
    expect(page).to have_content 'Rules'
  end
end