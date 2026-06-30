FactoryBot.define do
  factory :user do
    email_address { "user@example.com" }
    password { "password" }
    confirm_password { 'password' }
  end
end
