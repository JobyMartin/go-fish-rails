require 'rails_helper'

RSpec.fdescribe User, type: :model do
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
end
