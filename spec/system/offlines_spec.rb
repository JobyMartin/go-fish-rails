require 'rails_helper'

RSpec.describe 'Games', type: :system do
  context 'when the user goes to the offline show page' do
    it 'renders the offline show page' do
      sign_up
      visit offlines_path
      expect(page).to have_content "You're offline!"
    end
  end

  context 'when the user goes offline', :chrome do
    before do
      visit root_path
      wait_for_service_worker_control

      emulate_worker_network(offline: true)
    end
    it 'renders the offline show page' do
      visit root_path
      expect(page).to have_content "You're offline!"
      emulate_worker_network(offline: false)
    end
  end

  context 'when the user goes offline in a game' do
    before do
      sign_up
      sleep 0.1
      create_game
      start_game_with_opponent
    end
    it 'renders an offline alert', :chrome do
      wait_for_service_worker_control
      emulate_worker_network(offline: true)
      expect(page).to have_content 'You are offline'
      emulate_worker_network(offline: false)
      expect(page).not_to have_content 'You are offline'
    end
  end
end

def emulate_worker_network(offline:)
  network = page.driver.browser.devtools(target_type: 'service_worker').network
  network.enable
  network.emulate_network_conditions(offline: offline, latency: 0, download_throughput: -1, upload_throughput: -1)
end
def wait_for_service_worker_control
  Timeout.timeout(Capybara.default_max_wait_time) do
    sleep 0.1 until page.evaluate_script('navigator.serviceWorker.controller != null')
  end
end