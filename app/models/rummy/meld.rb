module Rummy
  class Meld
    RANK_ORDER = %w[A 2 3 4 5 6 7 8 9 10 J Q K].freeze

    attr_accessor :cards

    def initialize(cards = [])
      @cards = cards
    end

    def self.load(hash)
      return nil if hash.nil?

      cards = hash["cards"].map { |card| Card.load(card) }
      self.new(cards)
    end

    def self.valid_set?(cards)
      cards.size.between?(3, 4) && cards.map(&:rank).uniq.size == 1
    end

    def self.valid_run?(cards)
      return false if cards.size < 3 || cards.map(&:suit).uniq.size != 1

      positions = cards.map { RANK_ORDER.index(it.rank) }.sort
      positions.uniq.size == positions.size && positions == (positions.first..positions.last).to_a
    end

    def self.valid?(cards)
      valid_set?(cards) || valid_run?(cards)
    end
  end
end
