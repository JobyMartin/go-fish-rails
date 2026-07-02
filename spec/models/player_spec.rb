require 'rails_helper'

RSpec.describe Player, type: :model do
  let(:game) { create :game }
  let(:user) { create :user }
  let(:error_message) { 'You already joined the game' }
  it 'allows a player to join only once' do
    valid_player = build(:player, game:, user:)
    expect(valid_player).to be_valid
    valid_player.save

    invalid_player = build(:player, game:, user:)
    expect(invalid_player).to_not be_valid
    expect(invalid_player.errors.full_messages.to_sentence).to include(error_message)
  end
end
