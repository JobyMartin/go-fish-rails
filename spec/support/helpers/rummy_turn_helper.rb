module RummyTurnHelper
  def select_hand_card(token)
    click_retrying_stale_element { all("[data-rummy-turn-target='card'][data-card='#{token}']", minimum: 1).first.click }
  end

  def select_only_hand_card
    within(data_test('game-hand')) do
      click_retrying_stale_element { all("[data-rummy-turn-target='card']", minimum: 1).first.click }
    end
  end

  def hand_card_count
    all("#{data_test('game-hand')} #{data_test('card')}").count
  end

  def hand_card_prefixes
    all("#{data_test('game-hand')} img").map { card_filename_prefix(it['src']) }
  end

  def card_filename_prefix(src)
    File.basename(src).sub(/-\h+\.svg\z/, '')
  end

  def draw_and_discard(token)
    click_button 'Draw deck'
    select_hand_card(token)
    click_button 'Discard selected'
  end

  def meld_hearts_run
    click_button 'Draw deck'
    select_hand_card('3 Hearts')
    select_hand_card('4 Hearts')
    select_hand_card('5 Hearts')
    click_button 'Meld selected'
  end

  def discard_only_hand_card
    select_only_hand_card
    click_button 'Discard selected'
    expect(page).to have_no_css "#{data_test('game-hand')} #{data_test('card')}"
  end

  private

  def click_retrying_stale_element(attempts = 3)
    yield
  rescue Playwright::Error
    attempts -= 1
    raise if attempts.zero?

    retry
  end
end
