
module SignUpHelper
  def sign_up
    visit users_new_path

    fill_in 'email_address', with: 'user@example.com'
    fill_in 'password', with: 'password'
    fill_in 'confirm_password', with: 'password'

    click_on 'Sign up'
  end

  def invalid_sign_up
    visit users_new_path

    fill_in 'email_address', with: 'user@gmail.com'
    fill_in 'password', with: 'ertyujhj'
    fill_in 'confirm_password', with: '765tyjnbvrty'

    click_on 'Sign up'
  end
end
