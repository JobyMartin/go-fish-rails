module CrazyEights
  class William
    attr_accessor :cards
    def initialize(cards = [])
      @cards = cards
    end

    def active_card = cards.last

    def self.load(hash)
      cards = hash["cards"].map { |card_hash| Card.load(card_hash) }
      self.new(cards)
    end
  end
end
