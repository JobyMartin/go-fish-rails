module GoFish
  
  class Card
    attr_reader :rank, :suit, :value
    
    class InvalidRank < StandardError; end
    class InvalidSuit < StandardError; end
    
    # RANKS = %w( J Q K A )
    RANKS = %w( 2 3 4 5 6 7 8 9 10 J Q K A )
    SUITS = %w( Diamonds Hearts Spades Clubs )
    
    def initialize(rank, suit = 'Spades')
      raise InvalidRank unless RANKS.include? rank
      raise InvalidSuit unless SUITS.include? suit
      @rank = rank
      @suit = suit
      @value = RANKS.index(rank)
    end
    
    def ==(other_card)
      rank == other_card.rank && suit == other_card.suit
    end
    
    def to_s = "#{rank} of #{suit}"
      
    def to_pathname = "#{rank.downcase}_#{suit.downcase}.svg"
        
    def self.load(hash)
      self.new(hash['rank'], hash['suit'])
    end
  end
end