require 'rails_helper'

RSpec.describe Rummy::Meld, type: :model do
  let(:card1) { Card.new('7', 'Spades') }
  let(:card2) { Card.new('8', 'Spades') }
  let(:card3) { Card.new('9', 'Spades') }

  describe '.load' do
    it "rebuilds a meld's cards from a hash" do
      hash = { 'cards' => [ card1.as_json, card2.as_json, card3.as_json ] }
      loaded = Rummy::Meld.load(hash)
      expect(loaded.cards).to eq [ card1, card2, card3 ]
    end
  end
end
