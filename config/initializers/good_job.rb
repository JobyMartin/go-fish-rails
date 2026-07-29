Rails.configuration.after_initialize do
  ActiveJob::Base && ActiveRecord::Base
end

Rails.application.configure do
  config.good_job.cron = { example: { cron: "@hourly", class: "ArchiveGameJob"  } }
end
