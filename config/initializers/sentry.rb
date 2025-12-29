Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.release = Rails.application.config.git_full_hash
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f
  config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", 0.1).to_f
  config.send_default_pii = true
  config.enabled_environments = %w[production staging]
end
