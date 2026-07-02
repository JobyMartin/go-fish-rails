class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :players
  has_many :games, through: :players

  attribute :confirm_password

  validates :email_address, presence: true, uniqueness: { case_insensitive: true }, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_secure_password
  validates :password, length: { minimum: 8 }, allow_nil: true, comparison: { equal_to: :confirm_password }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
