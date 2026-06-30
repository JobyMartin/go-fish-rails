require 'rails_helper'

RSpec.describe 'Session', type: :system do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  it 'shows the login page' do
    visit new_session_path
    expect(page).to have_content 'Email'
    expect(page).to have_content 'Password'
  end
end
