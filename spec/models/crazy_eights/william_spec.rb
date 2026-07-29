require 'rails_helper'

RSpec.describe CrazyEights::William, type: :model do
  let(:william) { CrazyEights::William.new }
  let(:last_card) { Card.new('A', 'Spades') }

  describe '#active_card' do
    before do
      william.cards = [ Card.new('K', 'Hearts'), last_card ]
    end

    it 'returns the top card' do
      expect(william.active_card).to eq last_card
    end
  end
end
