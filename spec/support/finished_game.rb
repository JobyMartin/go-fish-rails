# Shared by the `:in_finished_game` player trait and the specs that assert on
# the time it produces, so a change to one can't silently break the other.
module FinishedGame
  DURATION = 1.day
end
