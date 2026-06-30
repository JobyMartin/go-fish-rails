class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: { case_insensitive: true }, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_secure_password
  validates :password, length: { minimum: 8 }, allow_nil: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
