module GoFish
  class Deck
    attr_reader :cards_left
    attr_accessor :cards 
    def initialize
      @cards = Card::SUITS.flat_map do |suit|
        Card::RANKS.map do |rank|
          Card.new(rank, suit)
        end
      end
  
      # @cards = []
    end
  
    def cards_left = cards.length
    def top_card = cards.shift
    def shuffle = cards.shuffle!
    def empty? = cards.empty?
  
    # for IRL testing (shorter game)
    def create_stacked_deck
      4.times do
        self.cards << Card.new('A', 'Spades')
        self.cards << Card.new('K', 'Spades')
        self.cards << Card.new('Q', 'Spades')
        self.cards << Card.new('J', 'Spades')
      end
    end
  end
end
