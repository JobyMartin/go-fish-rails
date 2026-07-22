module GoFish
  class RoundResult
    attr_reader :user_taken_from, :user_given_to, :cards_exchanged, :rank_in_question
    attr_accessor :went_fishing, :made_a_catch

    def initialize(current_user:, cards_exchanged:, user_in_question:, rank_in_question:, went_fishing:, made_a_catch:)
      @user_taken_from = user_in_question
      @rank_in_question = rank_in_question
      @user_given_to = current_user
      @cards_exchanged = cards_exchanged
      @went_fishing = went_fishing
      @made_a_catch = made_a_catch
    end

    def for_current_player
      went_fishing || made_a_catch ? message = [] : message = ["You asked #{user_taken_from.name} for any #{rank_in_question}s"]

      message << "\nGo fish!" if went_fishing
      message << "\nYou made a catch!" if made_a_catch

      message << "\nYou took #{cards_exchanged.map(&:to_s).join(', ')} from #{user_taken_from.name}" unless went_fishing || made_a_catch

      message
    end

    def for_other_players
      went_fishing || made_a_catch ? message = [] : message = ["#{user_given_to.name} asked #{user_taken_from.name} for any #{rank_in_question}s"]

      message << "\n#{user_given_to.name} went fishing!" if went_fishing
      message << "\n#{user_given_to.name} made a catch!" if made_a_catch

      message << "\n#{user_given_to.name} took #{cards_exchanged.map(&:to_s).join(', ')} from #{user_taken_from.name}" unless went_fishing || made_a_catch

      message
    end

    def feed_lines
      RoundFeed.new(for_other_players).lines
    end

    def self.load(hash)
      self.new(
        current_user: Player.load(hash['user_given_to']),
        cards_exchanged: hash['cards_exchanged'].map { |card| Card.load(card) },
        user_in_question: Player.load(hash['user_taken_from']),
        rank_in_question: hash['rank_in_question'],
        went_fishing: hash['went_fishing'],
        made_a_catch: hash['made_a_catch'],
      )
    end
  end
end
