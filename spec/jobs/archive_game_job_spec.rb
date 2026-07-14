require 'rails_helper'

RSpec.describe ArchiveGameJob, type: :job do
  include ActiveJob::TestHelper
  let(:expected_salty_fudge_size) { 2 }
  before do
    create :game
    create :game, :in_progress
    create :game, :ended
    create :game, :archived
    create :game, :stale
  end

  context 'when there are stale games' do
    it 'updates the archived_at column' do
      job = described_class.new
      job.perform
      expect(Game.all.where.not(archived_at: nil).size).to eq expected_salty_fudge_size
    end

    it 'it is idempotent' do
      job = described_class.new
      job.perform
      sleep 3
      job.perform
      expect(Game.all.where.not(archived_at: nil).size).to eq expected_salty_fudge_size
    end

    # it 'broadcasts updates to users' do
    #   job = described_class.new
    #   expect {
    #     perform_enqueued_jobs do
    #       job.perform
    #     end
    #   }.to have_broadcasted_to("games")
    # end
  end
end
