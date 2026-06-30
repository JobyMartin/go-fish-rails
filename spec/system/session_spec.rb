require 'rails_helper'

RSpec.fdescribe 'Session', type: :system do
  let(:user) { create(:user) }

  it 'shows the login page' do
    visit new_session_path
    expect(page).to have_content 'Email'
    expect(page).to have_content 'Password'
  end

  context 'when they click forgot password' do
    before do
      visit new_session_path
      click_on 'Forgot password?'
    end

    it 'redirects to the new password page' do
      expect(page).to have_current_path new_password_path
      expect(page).to have_content 'Forgot your password?'
    end
  end
end
