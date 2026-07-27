require "benchmark"

namespace :perf do
  desc "Seed bulk users/games/players for the leaderboard performance exercise"
  task :seed, %i[users games] => :environment do |_task, args|
    require Rails.root.join("lib/perf_seed")

    users = (args[:users] || 1_000).to_i
    games = (args[:games] || 5_000).to_i
    puts "Seeding #{users} users and #{games} games..."
    elapsed = Benchmark.realtime { PerfSeed.new(user_count: users, game_count: games).call }
    puts format("Done in %.1fs. Players: %d", elapsed, Player.count)
  end

  desc "Remove every record created by perf:seed"
  task clear: :environment do
    require Rails.root.join("lib/perf_seed")

    PerfSeed.clear
    puts "Cleared. Users: #{User.count}, Games: #{Game.count}, Players: #{Player.count}"
  end
end
