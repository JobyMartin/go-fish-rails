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

    context 'when the user clicks profile' do
      before do
        sign_up
        click_on 'Profile'
      end
      it 'sends them to their profile' do
        expect(page).to have_current_path users_show_path
        expect(page).to have_content 'Your profile'
      end
    end
  end

  context 'when the user signs up incorrectly' do
    it 'throws an error' do
      invalid_sign_up

      expect(page).to have_content 'Invalid signup'
    end
  end

  context 'when the email is already taken' do
    it 'shows user the error' do
      existing_user = create(:user, email_address: 'user@example.com')
      sign_up

      expect(page).to have_content 'has already been taken'
    end
  end

  xcontext 'when the password is invalid' do
    it 'shows user the error' do
      existing_user = create(:user, password: 'asdf')
      sign_up

      expect(page).to have_content 'Password is too short'
    end
  end

  xcontext 'when password confirmation does not match the password' do
    it 'shows user the error' do
      existing_user = create(:user, password: 'eightchars', confirm_password: 'eightchar')
      sign_up

      expect(page).to have_content 'must be equal to'
    end
  end
end
