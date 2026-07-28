module LeaderboardHelper
  def paged_entries(search) = search.result.page(params[:page])

  def rank_for(entries, index) = entries.offset_value + index + 1

  def win_percentage_for(entry)
    percentage = entry.win_percentage
    percentage.nil? ? LeaderboardEntry::UNRANKED : "#{percentage}%"
  end

  def time_played_for(entry)
    seconds = entry.time_played
    hours, remainder = seconds.divmod(1.hour)
    "#{hours}h #{(remainder / 1.minute).floor}m"
  end
end
