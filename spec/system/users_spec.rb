require 'rails_helper'

RSpec.fdescribe 'Users', type: :system do
  it 'shows the sign up content' do
    visit users_new_path
    expect(page).to have_current_path users_new_path
    expect(page).to have_content 'Already have an account?'
  end

  context 'when the user clicks sign in' do
    before do
      visit users_new_path
      click_on 'Sign in'
    end

    it 'redirects to the sign in page' do
      expect(page).to have_current_path new_session_path
      expect(page).to have_content 'Email'
      expect(page).to have_content 'Password'
    end
  end
end
