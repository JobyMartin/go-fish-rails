require 'rails_helper'

RSpec.describe User, type: :model do
  let(:valid_password) { 'grilledcheese' }
  let(:invalid_password) { 'cheeseburger' }

  context 'when bad email is provided' do
    let(:user) { build(:user, email_address: 'toast') }
    it 'is invalid' do
      expect(user).to be_invalid
    end
  end

  context 'when good email is provided' do
    let(:user) { build(:user, email_address: 'toast@grilledcheese.com', password: valid_password, confirm_password: valid_password) }
    it 'is valid' do
      expect(user).to be_valid
    end
  end

  context 'when bad password is provided' do
    let(:user) { build(:user, password: 'toast') }
    it 'is valid' do
      expect(user).to be_invalid
    end
  end

  context 'when good password is provided' do
    let(:user) { build(:user, password: valid_password, confirm_password: valid_password) }
    it 'is valid' do
      expect(user).to be_valid
    end
  end

  context 'when confirmation password does not match password' do
    let(:user) { build(:user, password: valid_password, confirm_password: invalid_password) }
    it 'is invalid' do
      expect(user).to be_invalid
    end
  end

  context 'when confirmation password matches password' do
    let(:user) { build(:user, password: valid_password, confirm_password: valid_password) }
    it 'is valid' do
      expect(user).to be_valid
    end
  end

  context 'when no username is provided' do
    let(:user) { build(:user, username: nil) }
    it 'is invalid' do
      expect(user).to be_invalid
    end
  end

  context 'when the username is already taken' do
    let(:taken_username) { 'ace' }
    before { create(:user, username: taken_username) }
    let(:user) { build(:user, username: taken_username.upcase) }

    it 'is invalid' do
      expect(user).to be_invalid
    end
  end
end
