require 'rails_helper'

RSpec.describe PerfSeed do
  let(:users) { 20 }
  let(:games) { 5 }

  def seed = described_class.new(user_count: users, game_count: games).call

  def seeded_users = User.where("username LIKE ?", "#{PerfSeed::USERNAME_PREFIX}%").order(:username)

  def countries = seeded_users.pluck(:country)

  it 'gives most seeded users a country' do
    seed

    expect(countries.compact.size).to be > users / 2
  end

  it 'leaves some seeded users without one' do
    seed

    expect(countries).to include nil
  end

  it 'only assigns countries the filter offers' do
    seed

    expect(countries.compact.uniq - Data::Country.all.map(&:id)).to be_empty
  end

  it 'assigns the same countries on a re-run' do
    seed
    first_run = countries

    seed

    expect(countries).to eq first_run
  end
end
