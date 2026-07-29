
module SignUpHelper
  def sign_up
    visit users_new_path

    fill_in 'Username', with: 'user'
    fill_in 'Email address', with: 'user@example.com'
    fill_in 'Password', with: 'password'
    fill_in 'Confirm password', with: 'password'

    click_on 'Sign up'
  end

  def invalid_sign_up
    visit users_new_path

    fill_in 'Username', with: 'user'
    fill_in 'Email address', with: 'user@gmail.com'
    fill_in 'Password', with: 'ertyujhj'
    fill_in 'Confirm password', with: '765tyjnbvrty'

    click_on 'Sign up'
  end
end
