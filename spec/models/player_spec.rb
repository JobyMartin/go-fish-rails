require 'rails_helper'

RSpec.describe Player, type: :model do
  let(:game) { create :game }
  let(:user) { create :user }
  it 'allows a player to join only once' do
    valid_player = build(:player, game:, user:)
    expect(valid_player).to be_valid
    valid_player.save

    invalid_player = build(:player, game:, user:)
    expect(invalid_player).to_not be_valid
    expect(invalid_player.errors.full_messages.to_sentence).to include(Player::JOINED_ERROR_MESSAGE)
  end

  context 'when the game has started' do
    before do
      game.start
    end

    it 'is invalid' do
      player = build(:player, game:, user:)
      expect(player).to be_invalid
    end
  end
end
