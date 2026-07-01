
module SignInHelper
  def sign_in(user)
    visit new_session_path

    fill_in 'Email address', with: user.email_address
    fill_in 'Password', with: user.password

    click_on 'Sign in'
  end
end
