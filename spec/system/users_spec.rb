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

  context 'when the user clicks edit' do
    before do
      sign_up
      click_on 'Profile'
    end

    it 'has the address form' do
      click_on 'Edit profile'
      expect(page).to have_field 'Country'
    end

    context 'when a country is selected' do
      before do
        click_on 'Edit profile'
      end

      it 'the correct states are added to the dropdown', :js do
        select 'United States', from: 'Country'
        expect(page).to have_select('State', with_options: [ 'North Carolina', 'Pennsylvania' ])
      end

      context 'when the user clicks save', :js do
        let(:user) { create :user }

        before do
          sign_in(user)
          visit edit_user_path(user)
        end

        it 'saves to the database', :js do
          select 'United States', from: 'Country'
          select 'North Carolina', from: 'State'

          click_on 'Update profile'
          sleep 0.1
          expect(user.reload.state).to eq 'NC'
        end
      end
    end
  end
end
