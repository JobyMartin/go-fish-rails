require "benchmark"
require Rails.root.join("lib/perf_seed")

# Query-count and timing harness for the leaderboard performance exercise
# (docs/leaderboard.md). Issues real requests through the full Rails stack so the
# view's per-row calls are counted too -- most of the leaderboard's N+1 lives in
# LeaderboardHelper, which a bare model benchmark would never touch.
class PerfMeasure
  DEFAULT_RUNS = 5
  PASSWORD = "password".freeze
  IGNORED_QUERIES = %w[SCHEMA TRANSACTION].freeze

  Run = Struct.new(:queries, :seconds)

  attr_reader :path, :runs, :user, :bullet

  def initialize(path:, runs: DEFAULT_RUNS, user: nil, bullet: false)
    @path = path
    @runs = runs
    @user = user || seeded_user
    @bullet = bullet
  end

  def call
    without_bullet do
      without_forgery_protection do
        session = sign_in
        request(session) # warm up: the first request pays for lazy loading
        Array.new(runs) { request(session) }
      end
    end
  end

  def report(results)
    puts "GET #{path} as #{user.username} -- #{runs} runs after warmup"
    puts format("  queries: %s", query_summary(results))
    puts format("  median:  %.0f ms", median(results.map(&:seconds)) * 1_000)
    puts format("  range:   %.0f-%.0f ms", results.map(&:seconds).min * 1_000,
                results.map(&:seconds).max * 1_000)
  end

  private

  def query_summary(results)
    counts = results.map(&:queries).uniq
    counts.one? ? counts.first.to_s : "#{results.map(&:queries).min}-#{results.map(&:queries).max} (varied)"
  end

  def median(values)
    sorted = values.sort
    sorted[sorted.size / 2]
  end

  # Only perf-seeded users have a known password; a real dev user would silently
  # fail sign-in and every request would measure the login page instead.
  def seeded_user
    User.where("username LIKE ?", "#{PerfSeed::USERNAME_PREFIX}%").order(:id).first ||
      raise("No seeded users found -- run `bin/rails perf:seed` first")
  end

  def sign_in
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host! "localhost"
    session.post "/session",
                 params: { session: { email_address: user.email_address, password: PASSWORD } }
    session.follow_redirect!
    verify(session, "sign-in")
    session
  end

  def request(session)
    queries = 0
    subscriber = subscribe { queries += 1 }
    seconds = Benchmark.realtime { session.get(path) }
    verify(session)
    Run.new(queries, seconds)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def subscribe(&increment)
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      increment.call unless payload[:cached] || IGNORED_QUERIES.include?(payload[:name])
    end
  end

  def verify(session, label = path)
    return if session.response.status == 200

    raise "#{label} returned #{session.response.status} (#{session.request.path})"
  end

  # Development keeps CSRF protection on, so posting to /session without a token is
  # a 422. Test env disables it for the same reason; this is that, scoped to the task.
  def without_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  # Bullet's own instrumentation is measurable overhead, and it is not part of what
  # production would spend on this page.
  def without_bullet
    return yield if bullet || !defined?(Bullet) || !Bullet.enable?

    Bullet.enable = false
    begin yield ensure Bullet.enable = true end
  end
end
