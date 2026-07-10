module CrazyEights
  class Game
    def initialize(players)
      @players = players
    end
    def self.load(json)

    end

    def self.dump(obj)
      obj.as_json
    end
  end
end