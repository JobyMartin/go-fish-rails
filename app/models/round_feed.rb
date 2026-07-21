class RoundFeed
  FeedLine = Struct.new(:text, :role)

  attr_reader :entries

  def initialize(entries)
    @entries = entries
  end

  def lines
    entries.each_with_index.map { |text, index| FeedLine.new(text, role_for(index)) }
  end

  private

  def role_for(index)
    return :action if index.zero?
    return :game_response if index == entries.size - 1

    :player_response
  end
end
