RSpec.configure do |config|
  Capybara.register_driver :playwright_headless do |app|
    create_driver(app)
  end

  Capybara.register_driver :chrome do |app|
    create_driver(app, headless: false)
  end

  Capybara.register_driver :firefox do |app|
    create_driver(app, browser_type: :firefox)
  end

  config.before(:each, type: :system) do
    driven_by :rack_test
    Capybara.default_max_wait_time = 2
  end

  config.before(:each, :js, type: :system) do
    driven_by :playwright_headless
    # first-request cold boot (autoloading + view compilation) can outrun
    # Capybara's 2s default wait, especially on the first page a spec visits
    Capybara.default_max_wait_time = 5
  end

  config.before(:each, :chrome, type: :system) do
    driven_by :selenium, using: :chrome
  end

  config.before(:each, :firefox, type: :system) do
    driven_by :firefox
  end

  config.after(:each, :chrome, type: :system) do
    devtools = page.driver.browser.devtools(target_type: 'page')
    devtools.service_worker.enable
    devtools.service_worker.stop_all_workers
  end

  def create_driver(app, options = {})
    default_options = {
      browser_type: :chromium,
      headless: true,
      viewport: { width: 1400, height: 1400 },
      browser_options: {
        args: [ '--disable-backgrounding-occluded-windows' ]
      }
    }

    merged_options = default_options.merge(options)
    Capybara::Playwright::Driver.new(app, **merged_options)
  end
end

# hide the annoying "Capybara starting Puma..." STDOUT message
Capybara.server = :puma, { Silent: true }

# try to remove any potential for parallel tests to conflict
Capybara.threadsafe = true
