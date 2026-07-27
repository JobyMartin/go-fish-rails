require "bcrypt"

# Bulk data generator for the leaderboard performance exercise (docs/leaderboard.md).
# Uses insert_all rather than factories: bcrypt at development cost makes per-user
# creation take minutes, and Player's `not_started` validation rejects players in
# already-started games, which every finished game here is.
class PerfSeed
  USERNAME_PREFIX = "perf_".freeze
  GAME_NAME_PREFIX = "Perf Game ".freeze
  FINISHED_RATIO = 0.7
  PLAYERS_PER_GAME = 2..4
  DURATION_RANGE = 5.minutes..90.minutes
  BATCH_SIZE = 1_000

  attr_reader :user_count, :game_count, :random, :now

  def initialize(user_count:, game_count:, seed: 20_260_727)
    @user_count = user_count
    @game_count = game_count
    @random = Random.new(seed)
    @now = Time.current
  end

  # Clears first so a re-run reproduces identical data. Without it, insert_players
  # re-picks players for every previously seeded game and piles new rows onto them —
  # the unique (game_id, user_id) index does not stop a fresh random draw.
  def call
    self.class.clear
    insert_users
    insert_games
    insert_players
    self
  end

  def self.clear
    Player.where(game: perf_games).delete_all
    perf_games.delete_all
    User.where("username LIKE ?", "#{USERNAME_PREFIX}%").delete_all
  end

  def self.perf_games
    Game.where("name LIKE ?", "#{GAME_NAME_PREFIX}%")
  end

  private

  def insert_users
    digest = BCrypt::Password.create("password", cost: BCrypt::Engine::MIN_COST)
    rows = Array.new(user_count) { user_row(it, digest) }
    insert_in_batches(User, rows)
  end

  def user_row(index, digest)
    { email_address: "#{USERNAME_PREFIX}#{index}@example.com",
      username: "#{USERNAME_PREFIX}#{index}", password_digest: digest,
      created_at: now, updated_at: now }
  end

  def insert_games
    finished_count = (game_count * FINISHED_RATIO).round
    rows = Array.new(game_count) { game_row(it, it < finished_count) }
    insert_in_batches(Game, rows)
  end

  def game_row(index, finished)
    started_at = now - random.rand(1..90).days
    { name: "#{GAME_NAME_PREFIX}#{index}", type: game_type,
      started_at: started_at, ended_at: (started_at + duration if finished),
      created_at: started_at, updated_at: started_at }
  end

  def game_type = Game::PLAYABLE_TYPES.keys.sample(random: random)

  def duration = random.rand(DURATION_RANGE)

  def insert_players
    user_ids = User.where("username LIKE ?", "#{USERNAME_PREFIX}%").pluck(:id)
    rows = self.class.perf_games.pluck(:id, :ended_at)
                 .flat_map { player_rows(it.first, it.last, user_ids) }
    insert_in_batches(Player, rows)
  end

  def player_rows(game_id, ended_at, user_ids)
    picked = pick_users(user_ids, random.rand(PLAYERS_PER_GAME))
    picked.map.with_index do |user_id, index|
      { game_id: game_id, user_id: user_id, created_at: now, updated_at: now,
        winner: (ended_at.present? && index.zero?) }
    end
  end

  # Squaring a uniform draw skews picks toward the front of the list, so some users
  # accumulate hundreds of games and others land under User::MINIMUM_RANKED_GAMES.
  # A flat distribution would put every user well past the ranking floor.
  def pick_users(user_ids, count)
    picked = Set.new
    picked << user_ids[(random.rand**2 * user_ids.size).to_i] while picked.size < count
    picked.to_a
  end

  def insert_in_batches(model, rows)
    rows.each_slice(BATCH_SIZE) { model.insert_all(it) }
  end
end
