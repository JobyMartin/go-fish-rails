class Deck
  attr_reader :cards_left
  attr_accessor :cards
  def initialize
    @cards = Card::SUITS.flat_map do |suit|
      Card::RANKS.map do |rank|
        Card.new(rank, suit)
      end
    end.shuffle
  end

  def self.load(hash)
    deck = self.new
    deck.cards = hash["cards"].map { |card| Card.load(card) }
    deck
  end

  def cards_left = cards.length
  def top_card = cards.shift
  def shuffle = cards.shuffle!
  def empty? = cards.empty?
end
