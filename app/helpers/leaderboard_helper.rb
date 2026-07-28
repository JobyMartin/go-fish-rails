module LeaderboardHelper
  def win_percentage_for(entry)
    percentage = entry.win_percentage
    percentage.nil? ? User::UNRANKED : "#{percentage}%"
  end

  def time_played_for(entry)
    seconds = entry.time_played
    hours, remainder = seconds.divmod(1.hour)
    "#{hours}h #{(remainder / 1.minute).floor}m"
  end
end
