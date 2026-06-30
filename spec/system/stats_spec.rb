require 'rails_helper'

RSpec.describe 'Stats', type: :system do
  it 'shows the stats' do
    visit stats_path
    expect(page).to have_content 'Your Go Fish Statistics'
  end
end