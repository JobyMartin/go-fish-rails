require 'rails_helper'

RSpec.describe User, type: :model do
  context 'when bad email is provided' do
    let(:user) { build(:user, email_address: 'toast') }
    it 'is invalid' do
      expect(user).to be_invalid
    end
  end

  context 'when good email is provided' do
    let(:user) { build(:user, email_address: 'toast@grilledcheese.com') }
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
    let(:user) { build(:user, password: 'grilledcheese') }
    it 'is valid' do
      expect(user).to be_valid
    end
  end
end
