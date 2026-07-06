module GoFish
  class Game
    attr_accessor :players

    def initialize(players)
      @players = players
    end

    def as_json
      {
        players: players.map(&:as_json)
      }
    end

    def self.from_json(json)
      players = json[:players].map { |player_hash| Player.load(player_hash) }
      self.new(players)
    end

    def self.load(json)
      return if json.blank?

      from_json(json)
    end

    def self.dump(obj)
      obj.as_json
    end
  end
end