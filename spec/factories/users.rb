FactoryBot.define do
  factory :user do
    sequence :email_address do |n|
      "person#{n}@example.com"
    end

    sequence :username do |n|
      "person#{n}"
    end

    password { "password" }
    confirm_password { 'password' }
  end
end
