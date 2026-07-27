
module SignInHelper
  MAX_SIGN_IN_ATTEMPTS = 3

  def sign_in(user)
    attempts = 0

    begin
      attempts += 1
      attempt_sign_in(user)
    end while page.has_button?('Sign in', wait: 2) && attempts < MAX_SIGN_IN_ATTEMPTS
  end

  private

  def attempt_sign_in(user)
    visit new_session_path

    fill_in 'Email address', with: user.email_address
    fill_in 'Password', with: user.password

    click_on 'Sign in'
  end
end
