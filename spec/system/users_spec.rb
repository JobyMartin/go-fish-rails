require 'rails_helper'

RSpec.describe 'Users', type: :system do
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

  context 'when the user signs up correctly' do
    it 'sends them to the home page and adds them to the database' do
      expect do
        sign_up
        expect(page).to have_current_path root_path
      end.to change(User, :count).by 1
    end
  end

  context 'when the user signs up incorrectly' do
    it 'throw an error' do
      invalid_sign_up

      expect(page).to have_content 'Invalid signup'
    end
  end
end
